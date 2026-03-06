import Foundation

extension FeedManager {

    // MARK: - Article Queries

    func todayArticles() -> [Article] {
        _ = dataRevision
        let startOfToday = Calendar.current.startOfDay(for: Date())
        var all = (try? database.allArticles(since: startOfToday)) ?? []
        let muted = mutedFeedIDs
        if !muted.isEmpty {
            all = all.filter { !muted.contains($0.feedID) }
        }
        return applyAllRules(all)
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

    func olderArticles(limit: Int = 200) -> [Article] {
        _ = dataRevision
        let startOfToday = Calendar.current.startOfDay(for: Date())
        var all = (try? database.allArticles(before: startOfToday, limit: limit)) ?? []
        let muted = mutedFeedIDs
        if !muted.isEmpty {
            all = all.filter { !muted.contains($0.feedID) }
        }
        return applyAllRules(all)
    }

    func articles(for feed: Feed, limit: Int? = nil) -> [Article] {
        _ = dataRevision
        let all = (try? database.articles(forFeedID: feed.id, limit: limit)) ?? []
        return applyRules(all, feedID: feed.id)
    }

    func articleCount(for feed: Feed) -> Int {
        _ = dataRevision
        return (try? database.articleCount(forFeedID: feed.id)) ?? 0
    }

    // MARK: - Read / Bookmark State

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
        let mutedFeedIDs = Set(feeds.filter(\.isMuted).map(\.id))
        if mutedFeedIDs.isEmpty {
            return (try? database.totalUnreadCount()) ?? 0
        }
        return feeds.filter { !$0.isMuted }.reduce(0) { total, feed in
            total + ((try? database.unreadCount(forFeedID: feed.id)) ?? 0)
        }
    }

    // MARK: - Filtering Helpers

    private func filterExcludingPodcastsAndVideos(_ articles: [Article]) -> [Article] {
        let excludedFeedIDs = Set(feeds.filter { feed in
            feed.isMuted || feed.isPodcast || VideoDomains.shouldPreferVideo(feedDomain: feed.domain)
        }.map(\.id))
        return articles.filter { !excludedFeedIDs.contains($0.feedID) }
    }
}
