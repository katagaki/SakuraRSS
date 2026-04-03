import Foundation
import SwiftUI
@preconcurrency import UserNotifications

@Observable
final class FeedManager {

    var feeds: [Feed] = []
    var articles: [Article] = []
    var isLoading = false
    private(set) var dataRevision: Int = 0
    private(set) var faviconRevision: Int = 0
    private(set) var unreadCounts: [Int64: Int] = [:]
    private(set) var feedsByID: [Int64: Feed] = [:]

    let database = DatabaseManager.shared

    init() {
        loadFromDatabase()
    }

    func loadFromDatabase() {
        do {
            feeds = try database.allFeeds()
            feedsByID = Dictionary(uniqueKeysWithValues: feeds.map { ($0.id, $0) })
            articles = try database.allArticles(limit: 200)
            unreadCounts = (try? database.allUnreadCounts()) ?? [:]
            dataRevision += 1
        } catch {
            print("Failed to load from database: \(error)")
        }
    }

    func loadFromDatabaseInBackground() async {
        let db = database
        do {
            let (loadedFeeds, loadedArticles, loadedUnreadCounts) = try await Task.detached {
                let feeds = try db.allFeeds()
                let articles = try db.allArticles(limit: 200)
                let unreadCounts = (try? db.allUnreadCounts()) ?? [:]
                return (feeds, articles, unreadCounts)
            }.value
            await MainActor.run {
                self.feeds = loadedFeeds
                self.feedsByID = Dictionary(uniqueKeysWithValues: loadedFeeds.map { ($0.id, $0) })
                self.articles = loadedArticles
                self.unreadCounts = loadedUnreadCounts
                self.dataRevision += 1
            }
        } catch {
            print("Failed to load from database: \(error)")
        }
    }

    // MARK: - Feed CRUD

    func addFeed(url: String, title: String, siteURL: String,
                 description: String = "", faviconURL: String? = nil,
                 category: String? = nil, isPodcast: Bool = false) throws {
        let feedID = try database.insertFeed(
            title: title, url: url, siteURL: siteURL,
            description: description, faviconURL: faviconURL,
            category: category, isPodcast: isPodcast
        )
        generateAcronymIcon(feedID: feedID, title: title)
        loadFromDatabase()
    }

    func deleteFeed(_ feed: Feed) throws {
        try database.deleteFeed(id: feed.id)
        loadFromDatabase()
    }

    func toggleMuted(_ feed: Feed) {
        try? database.updateFeedMuted(id: feed.id, isMuted: !feed.isMuted)
        loadFromDatabase()
    }

    func updateFeedDetails(_ feed: Feed, title: String, url: String,
                           customIconURL: String?) {
        try? database.updateFeedDetails(id: feed.id, title: title, url: url,
                                        customIconURL: customIconURL)
        if title != feed.title {
            generateAcronymIcon(feedID: feed.id, title: title)
        }
        loadFromDatabase()
    }

    // MARK: - Feed Refresh

    func refreshFeed(_ feed: Feed, updateTitle: Bool = true, reloadData: Bool = true) async throws {
        if feed.isXFeed {
            guard UserDefaults.standard.bool(forKey: "Labs.XProfileFeeds") else { return }
            try await refreshXFeed(feed, reloadData: reloadData)
            return
        }

        let db = database
        try await Task.detached {
            guard let url = URL(string: feed.url) else { return }

            let (data, _) = try await URLSession.shared.data(from: url)
            let parser = RSSParser()
            guard let parsed = parser.parse(data: data) else { return }

            let articleTuples = parsed.articles.map { article in
                (
                    title: article.title,
                    url: article.url,
                    data: ArticleInsertData(
                        author: article.author,
                        summary: article.summary,
                        content: article.content,
                        imageURL: article.imageURL,
                        publishedDate: article.publishedDate,
                        audioURL: article.audioURL,
                        duration: article.duration
                    )
                )
            }

            try db.insertArticles(feedID: feed.id, articles: articleTuples)

            if parsed.allArticlesHaveAudio && !feed.isPodcast {
                try db.updateFeedIsPodcast(id: feed.id, isPodcast: true)
            } else if !parsed.allArticlesHaveAudio && feed.isPodcast {
                try db.updateFeedIsPodcast(id: feed.id, isPodcast: false)
            }
            if updateTitle, !parsed.title.isEmpty, parsed.title != feed.title {
                try db.updateFeed(id: feed.id, title: parsed.title, category: feed.category)
            }
            try db.updateFeedLastFetched(id: feed.id, date: Date())
        }.value
        if reloadData {
            await loadFromDatabaseInBackground()
        }
    }

    func deleteAllArticlesAndRefresh() async {
        let db = database
        _ = try? await Task.detached { try db.deleteAllArticles() }.value
        await loadFromDatabaseInBackground()
        await refreshAllFeeds()
    }

    func refreshAllFeeds() async {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in self.isLoading = false } }

        let currentFeeds = feeds
        await withTaskGroup(of: Void.self) { group in
            for feed in currentFeeds {
                group.addTask {
                    try? await self.refreshFeed(feed, reloadData: false)
                }
            }
        }
        await loadFromDatabaseInBackground()
    }

    func refreshAllFeedsAndFavicons() async {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in self.isLoading = false } }

        let currentFeeds = feeds
        async let feedRefresh: Void = withTaskGroup(of: Void.self) { group in
            for feed in currentFeeds {
                group.addTask {
                    try? await self.refreshFeed(feed, updateTitle: false, reloadData: false)
                }
            }
        }
        async let faviconRefresh: Void = FaviconCache.shared.refreshFavicons(
            for: currentFeeds.map { ($0.domain, $0.siteURL as String?) }
        )
        _ = await (feedRefresh, faviconRefresh)
        await loadFromDatabaseInBackground()
        regenerateAllAcronymIcons()
        faviconRevision += 1
    }

    // MARK: - Badge

    func updateBadgeCount() {
        let mode = UserDefaults.standard.string(forKey: "Display.UnreadBadgeMode") ?? "homeScreenAndHomeTab"
        let center = UNUserNotificationCenter.current()
        guard mode == "homeScreenAndHomeTab" || mode == "homeScreenOnly" else {
            Task { try? await center.setBadgeCount(0) }
            return
        }
        Task {
            let settings = await center.notificationSettings()
            guard settings.badgeSetting == .enabled else { return }
            let count = self.totalUnreadCount()
            try? await center.setBadgeCount(count)
        }
    }

    // MARK: - Lookups

    var mutedFeedIDs: Set<Int64> {
        Set(feeds.filter(\.isMuted).map(\.id))
    }

    func feed(forArticle article: Article) -> Feed? {
        feedsByID[article.feedID]
    }

    func article(byID id: Int64) -> Article? {
        articles.first { $0.id == id } ?? (try? database.article(byID: id))
    }

    // MARK: - Acronym Icons

    func generateAcronymIcon(feedID: Int64, title: String) {
        guard let image = InitialsAvatarView.renderToImage(name: title),
              let pngData = image.pngData() else { return }
        try? database.updateFeedAcronymIcon(id: feedID, data: pngData)
    }

    func regenerateAllAcronymIcons() {
        for feed in feeds {
            generateAcronymIcon(feedID: feed.id, title: feed.title)
        }
    }

}
