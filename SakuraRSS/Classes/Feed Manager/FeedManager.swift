import CoreSpotlight
import Foundation
import SwiftUI
@preconcurrency import UserNotifications

@Observable
final class FeedManager {

    var feeds: [Feed] = []
    var articles: [Article] = []
    var lists: [FeedList] = []
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
            lists = (try? database.allLists()) ?? []
            dataRevision += 1
        } catch {
            print("Failed to load from database: \(error)")
        }
    }

    func loadFromDatabaseInBackground() async {
        let dbm = database
        do {
            let (loadedFeeds, loadedArticles, loadedUnreadCounts, loadedLists) = try await Task.detached {
                let feeds = try dbm.allFeeds()
                let articles = try dbm.allArticles(limit: 200)
                let unreadCounts = (try? dbm.allUnreadCounts()) ?? [:]
                let lists = (try? dbm.allLists()) ?? []
                return (feeds, articles, unreadCounts, lists)
            }.value
            await MainActor.run {
                self.feeds = loadedFeeds
                self.feedsByID = Dictionary(uniqueKeysWithValues: loadedFeeds.map { ($0.id, $0) })
                self.articles = loadedArticles
                self.unreadCounts = loadedUnreadCounts
                self.lists = loadedLists
                self.dataRevision += 1
            }
        } catch {
            print("Failed to load from database: \(error)")
        }
    }

    /// Notify the UI that favicons may have changed so views re-fetch them.
    func notifyFaviconChange() {
        faviconRevision += 1
    }

    // MARK: - Feed CRUD

    func addFeed(url: String, title: String, siteURL: String,
                 description: String = "", faviconURL: String? = nil,
                 category: String? = nil, isPodcast: Bool = false) throws {
        guard !database.feedExists(url: url) else {
            throw FeedError.alreadyExists
        }
        let feedID = try database.insertFeed(
            title: title, url: url, siteURL: siteURL,
            description: description, faviconURL: faviconURL,
            category: category, isPodcast: isPodcast
        )
        generateAcronymIcon(feedID: feedID, title: title)
        loadFromDatabase()
        // Fetch the feed's articles in the background
        if let feed = feedsByID[feedID] {
            Task {
                try? await refreshFeed(feed)
            }
        }
    }

    func deleteFeed(_ feed: Feed) throws {
        let articleIDs = (try? database.articles(forFeedID: feed.id)).map { $0.map(\.id) } ?? []
        try database.deleteFeed(id: feed.id)
        PodcastDownloadManager.cleanupOrphanedDownloads()
        SpotlightIndexer.removeArticles(feedID: feed.id, articleIDs: articleIDs)
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

        if feed.isInstagramFeed {
            guard UserDefaults.standard.bool(forKey: "Labs.InstagramProfileFeeds") else { return }
            try await refreshInstagramFeed(feed, reloadData: reloadData)
            return
        }

        if feed.isYouTubePlaylistFeed {
            try await refreshYouTubePlaylistFeed(feed, reloadData: reloadData)
            return
        }

        let database = database
        try await Task.detached {
            guard let url = URL(string: feed.url) else { return }
            let fetchURL = RedirectDomains.redirectedURL(url)

            let (data, _) = try await URLSession.shared.data(from: fetchURL)
            let parser = RSSParser()
            guard let parsed = parser.parse(data: data) else { return }

            let articleTuples = parsed.articles.map { article in
                ArticleInsertItem(
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

            try database.insertArticles(feedID: feed.id, articles: articleTuples)

            let feedTitleForIndex = parsed.title.isEmpty ? feed.title : parsed.title
            let articlesToIndex = try database.articles(forFeedID: feed.id, limit: articleTuples.count)
            SpotlightIndexer.indexArticles(articlesToIndex, feedTitle: feedTitleForIndex)

            if parsed.isPodcast && !feed.isPodcast {
                try database.updateFeedIsPodcast(id: feed.id, isPodcast: true)
            } else if !parsed.isPodcast && feed.isPodcast {
                try database.updateFeedIsPodcast(id: feed.id, isPodcast: false)
            }
            if updateTitle, !parsed.title.isEmpty, parsed.title != feed.title {
                try database.updateFeed(id: feed.id, title: parsed.title, category: feed.category)
            }
            try database.updateFeedLastFetched(id: feed.id, date: Date())
        }.value
        if reloadData {
            await loadFromDatabaseInBackground()
        }
    }

    func deleteAllArticlesAndRefresh() async {
        let database = database
        _ = try? await Task.detached { try database.deleteAllArticles() }.value
        SpotlightIndexer.removeAllArticles()
        await loadFromDatabaseInBackground()
        await refreshAllFeeds()
    }

    func reindexAllArticlesInSpotlight() {
        let database = database
        let allFeeds = feeds
        Task.detached(priority: .utility) {
            for feed in allFeeds {
                if let articles = try? database.articles(forFeedID: feed.id) {
                    SpotlightIndexer.indexArticles(articles, feedTitle: feed.title)
                }
            }
        }
    }

    func deleteArticlesAndVacuum(olderThan date: Date?) async {
        let cutoff = date ?? Date()
        UserDefaults.standard.set(cutoff.timeIntervalSince1970, forKey: "Content.CutoffDate")
        let database = database
        _ = try? await Task.detached {
            if let date {
                try database.deleteArticles(olderThan: date)
                try database.clearImageCache(olderThan: date)
            } else {
                try database.deleteAllArticlesOnly()
                try database.clearImageCache()
            }
            try database.vacuum()
            PodcastDownloadManager.cleanupOrphanedDownloads()
        }.value
        SpotlightIndexer.removeAllArticles()
        await loadFromDatabaseInBackground()
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

    /// Refreshes feeds that have never been fetched (e.g. added by the share
    /// extension while the main app was in the background).  Also generates
    /// acronym icons and fetches favicons for those feeds.
    func refreshUnfetchedFeeds() async {
        let unfetched = feeds.filter { $0.lastFetched == nil }
        guard !unfetched.isEmpty else { return }

        // Generate acronym icons the share extension doesn't create.
        for feed in unfetched {
            generateAcronymIcon(feedID: feed.id, title: feed.title)
        }

        // Fetch articles for the new feeds.
        await withTaskGroup(of: Void.self) { group in
            for feed in unfetched {
                group.addTask {
                    try? await self.refreshFeed(feed, reloadData: false)
                }
            }
        }
        await loadFromDatabaseInBackground()

        // Clear any stale favicon failures and notify the UI so
        // FeedRowViews re-fetch their icons.
        let entries = unfetched.map { ($0.domain, $0.siteURL as String?) }
        await FaviconCache.shared.clearFailedLookups(for: entries)
        faviconRevision += 1
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
        let mode = UserDefaults.standard.string(forKey: "Display.UnreadBadgeMode") ?? "none"
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

enum FeedError: LocalizedError {
    case alreadyExists

    var errorDescription: String? {
        switch self {
        case .alreadyExists:
            String(localized: "FeedError.AlreadyExists")
        }
    }
}
