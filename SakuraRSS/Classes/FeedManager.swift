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

    private let database = DatabaseManager.shared

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

    func addFeed(url: String, title: String, siteURL: String,
                 description: String = "", faviconURL: String? = nil,
                 category: String? = nil, isPodcast: Bool = false) throws {
        try database.insertFeed(
            title: title, url: url, siteURL: siteURL,
            description: description, faviconURL: faviconURL,
            category: category, isPodcast: isPodcast
        )
        loadFromDatabase()
    }

    func deleteFeed(_ feed: Feed) throws {
        try database.deleteFeed(id: feed.id)
        loadFromDatabase()
    }

    func refreshFeed(_ feed: Feed) async throws {
        guard let url = URL(string: feed.url) else { return }

        let (data, _) = try await URLSession.shared.data(from: url)
        let parser = RSSParser()
        guard let parsed = parser.parse(data: data) else { return }

        for article in parsed.articles {
            try database.insertArticle(
                feedID: feed.id,
                title: article.title,
                url: article.url,
                author: article.author,
                summary: article.summary,
                content: article.content,
                imageURL: article.imageURL,
                publishedDate: article.publishedDate,
                audioURL: article.audioURL,
                duration: article.duration
            )
        }

        if parsed.isPodcast != feed.isPodcast {
            try database.updateFeedIsPodcast(id: feed.id, isPodcast: parsed.isPodcast)
        }
        if !parsed.title.isEmpty && parsed.title != feed.title {
            try database.updateFeed(id: feed.id, title: parsed.title, category: feed.category)
        }
        try database.updateFeedLastFetched(id: feed.id, date: Date())
        loadFromDatabase()
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
                    try? await self.refreshFeed(feed)
                }
            }
        }
        async let faviconRefresh: Void = FaviconCache.shared.refreshFavicons(
            for: currentFeeds.map { ($0.domain, $0.siteURL as String?) }
        )
        _ = await (feedRefresh, faviconRefresh)
        loadFromDatabase()
        faviconRevision += 1
    }

    func todayArticles() -> [Article] {
        _ = dataRevision
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return (try? database.allArticles(since: startOfToday)) ?? []
    }

    func overnightArticles() -> [Article] {
        _ = dataRevision
        let calendar = Calendar.current
        let now = Date()
        let midnight = calendar.startOfDay(for: now)
        let allOvernight = (try? database.allArticles(from: midnight, to: now)) ?? []
        return filterExcludingPodcastsAndVideos(allOvernight)
    }

    func todaySummaryArticles() -> [Article] {
        _ = dataRevision
        let midnight = Calendar.current.startOfDay(for: Date())
        let allToday = (try? database.allArticles(from: midnight, to: Date())) ?? []
        return filterExcludingPodcastsAndVideos(allToday)
    }

    private func filterExcludingPodcastsAndVideos(_ articles: [Article]) -> [Article] {
        let excludedFeedIDs = Set(feeds.filter { feed in
            feed.isPodcast || VideoDomains.shouldPreferVideo(feedDomain: feed.domain)
        }.map(\.id))
        return articles.filter { !excludedFeedIDs.contains($0.feedID) }
    }

    func olderArticles(limit: Int = 200) -> [Article] {
        _ = dataRevision
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return (try? database.allArticles(before: startOfToday, limit: limit)) ?? []
    }

    func articles(for feed: Feed) -> [Article] {
        _ = dataRevision
        return (try? database.articles(forFeedID: feed.id)) ?? []
    }

    func markRead(_ article: Article) {
        try? database.markArticleRead(id: article.id, read: true)
        loadFromDatabase()
        updateBadgeCount()
    }

    func toggleRead(_ article: Article) {
        try? database.markArticleRead(id: article.id, read: !article.isRead)
        loadFromDatabase()
        updateBadgeCount()
    }

    func toggleBookmark(_ article: Article) {
        try? database.toggleBookmark(id: article.id)
        loadFromDatabase()
    }

    func markAllRead(feed: Feed) {
        try? database.markAllRead(feedID: feed.id)
        loadFromDatabase()
        updateBadgeCount()
    }

    func markAllRead() {
        try? database.markAllRead()
        loadFromDatabase()
        updateBadgeCount()
    }

    func unreadCount(for feed: Feed) -> Int {
        _ = dataRevision
        return (try? database.unreadCount(forFeedID: feed.id)) ?? 0
    }

    func totalUnreadCount() -> Int {
        _ = dataRevision
        return (try? database.totalUnreadCount()) ?? 0
    }

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

    func feed(forArticle article: Article) -> Feed? {
        feeds.first { $0.id == article.feedID }
    }

    func article(byID id: Int64) -> Article? {
        articles.first { $0.id == id } ?? (try? database.article(byID: id))
    }

    // MARK: - OPML Export

    func exportOPML() -> String {
        OPMLManager.shared.generateOPML(from: feeds)
    }

    // MARK: - OPML Import

    func importOPML(data: Data, overwrite: Bool) throws -> Int {
        let opmlFeeds = OPMLManager.shared.parseOPML(data: data)
        guard !opmlFeeds.isEmpty else { return 0 }

        if overwrite {
            let existing = try database.allFeeds()
            for feed in existing {
                try database.deleteFeed(id: feed.id)
            }
        }

        var added = 0
        for opmlFeed in opmlFeeds {
            if database.feedExists(url: opmlFeed.xmlURL) {
                continue
            }
            try database.insertFeed(
                title: opmlFeed.title,
                url: opmlFeed.xmlURL,
                siteURL: opmlFeed.htmlURL,
                description: opmlFeed.description,
                category: opmlFeed.category
            )
            added += 1
        }

        loadFromDatabase()
        return added
    }
}
