import Foundation
import SwiftUI

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
                 category: String? = nil) throws {
        try database.insertFeed(
            title: title, url: url, siteURL: siteURL,
            description: description, faviconURL: faviconURL,
            category: category
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
                publishedDate: article.publishedDate
            )
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
    }

    func toggleRead(_ article: Article) {
        try? database.markArticleRead(id: article.id, read: !article.isRead)
        loadFromDatabase()
    }

    func toggleBookmark(_ article: Article) {
        try? database.toggleBookmark(id: article.id)
        loadFromDatabase()
    }

    func markAllRead(feed: Feed) {
        try? database.markAllRead(feedID: feed.id)
        loadFromDatabase()
    }

    func markAllRead() {
        try? database.markAllRead()
        loadFromDatabase()
    }

    func unreadCount(for feed: Feed) -> Int {
        _ = dataRevision
        return (try? database.unreadCount(forFeedID: feed.id)) ?? 0
    }

    func totalUnreadCount() -> Int {
        _ = dataRevision
        return (try? database.totalUnreadCount()) ?? 0
    }

    func feed(forArticle article: Article) -> Feed? {
        feeds.first { $0.id == article.feedID }
    }
}
