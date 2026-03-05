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

    let database = DatabaseManager.shared

    init() {
        loadFromDatabase()
    }

    func loadFromDatabase() {
        do {
            feeds = try database.allFeeds()
            articles = try database.allArticles(limit: 200)
            dataRevision += 1
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

    func refreshFeed(_ feed: Feed, updateTitle: Bool = true) async throws {
        if feed.isXFeed {
            guard UserDefaults.standard.bool(forKey: "Experiments.XProfileFeeds") else { return }
            try await refreshXFeed(feed)
            return
        }

        guard let url = URL(string: feed.url) else { return }

        let (data, _) = try await URLSession.shared.data(from: url)
        let parser = RSSParser()
        guard let parsed = parser.parse(data: data) else { return }

        for article in parsed.articles {
            try database.insertArticle(
                feedID: feed.id,
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

        if parsed.allArticlesHaveAudio && !feed.isPodcast {
            try database.updateFeedIsPodcast(id: feed.id, isPodcast: true)
        } else if !parsed.allArticlesHaveAudio && feed.isPodcast {
            try database.updateFeedIsPodcast(id: feed.id, isPodcast: false)
        }
        if updateTitle, !parsed.title.isEmpty, parsed.title != feed.title {
            try database.updateFeed(id: feed.id, title: parsed.title, category: feed.category)
        }
        try database.updateFeedLastFetched(id: feed.id, date: Date())
        loadFromDatabase()
    }

    func deleteAllArticlesAndRefresh() async {
        try? database.deleteAllArticles()
        loadFromDatabase()
        await refreshAllFeeds()
    }

    func refreshAllFeeds() async {
        isLoading = true
        defer { isLoading = false }

        let currentFeeds = feeds
        await withTaskGroup(of: Void.self) { group in
            for feed in currentFeeds {
                group.addTask {
                    try? await self.refreshFeed(feed)
                }
            }
        }
        loadFromDatabase()
    }

    func refreshAllFeedsAndFavicons() async {
        isLoading = true
        defer { isLoading = false }

        let currentFeeds = feeds
        async let feedRefresh: Void = withTaskGroup(of: Void.self) { group in
            for feed in currentFeeds {
                group.addTask {
                    try? await self.refreshFeed(feed, updateTitle: false)
                }
            }
        }
        async let faviconRefresh: Void = FaviconCache.shared.refreshFavicons(
            for: currentFeeds.map { ($0.domain, $0.siteURL as String?) }
        )
        _ = await (feedRefresh, faviconRefresh)
        loadFromDatabase()
        regenerateAllAcronymIcons()
        loadFromDatabase()
        faviconRevision += 1
    }

    // MARK: - Badge

    func updateBadgeCount() {
        let badgeEnabled = UserDefaults.standard.bool(forKey: "BackgroundRefresh.BadgeEnabled")
        let center = UNUserNotificationCenter.current()
        guard badgeEnabled else {
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
        feeds.first { $0.id == article.feedID }
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
