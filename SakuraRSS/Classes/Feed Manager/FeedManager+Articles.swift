import Foundation

extension FeedManager {

    // MARK: - Chunk Boundaries

    /// Safety cap for chunk-walking loops — two years' worth of 24-hour
    /// chunks. Hitting this means the walk has skipped past every populated
    /// chunk in that window without finding visible content.
    static var chunkWalkLimit: Int { 365 * 2 }

    /// Articles are paginated in 24-hour chunks. Returns the chunk boundary
    /// (00:00 local) at or before `date`.
    static func chunkStart(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    static func chunkEnd(for chunkStart: Date) -> Date {
        Calendar.current.date(byAdding: .hour, value: 24, to: chunkStart) ?? chunkStart
    }

    static func currentChunkStart() -> Date {
        chunkStart(for: Date())
    }

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

    func articles(for feed: Feed, since date: Date) -> [Article] {
        _ = dataRevision
        let all = (try? database.articles(forFeedID: feed.id, since: date)) ?? []
        return applyRules(all, feedID: feed.id)
    }

    func undatedArticles(for feed: Feed) -> [Article] {
        _ = dataRevision
        let all = (try? database.undatedArticles(forFeedID: feed.id)) ?? []
        return applyRules(all, feedID: feed.id)
    }

    func nextArticleChunk(for feed: Feed, before date: Date) -> Date? {
        _ = dataRevision
        var cursor = date
        var iterations = 0
        while iterations < FeedManager.chunkWalkLimit {
            iterations += 1
            guard let earlier = (try? database.earliestArticleDate(forFeedID: feed.id, before: cursor)) ?? nil else {
                return nil
            }
            let chunkStart = FeedManager.chunkStart(for: earlier)
            guard chunkStart < cursor else { return nil }
            let chunkEnd = FeedManager.chunkEnd(for: chunkStart)
            let chunkArticles = (try? database.articles(forFeedID: feed.id, since: chunkStart)) ?? []
            let inChunk = chunkArticles.filter { ($0.publishedDate ?? .distantPast) < chunkEnd }
            if !applyRules(inChunk, feedID: feed.id).isEmpty {
                return chunkStart
            }
            cursor = chunkStart
        }
        return nil
    }

    func articleCount(for feed: Feed) -> Int {
        _ = dataRevision
        return (try? database.articleCount(forFeedID: feed.id)) ?? 0
    }

    func articles(since date: Date) -> [Article] {
        _ = dataRevision
        var all = (try? database.allArticles(since: date, limit: nil)) ?? []
        let muted = mutedFeedIDs
        if !muted.isEmpty {
            all = all.filter { !muted.contains($0.feedID) }
        }
        return applyAllRules(all)
    }

    func nextArticleChunk(before date: Date) -> Date? {
        _ = dataRevision
        let muted = mutedFeedIDs
        var cursor = date
        var iterations = 0
        // Walk backwards past chunks where every article is muted. The cursor
        // must strictly decrease each iteration; the cap is a belt-and-braces
        // guard against calendar edge cases so a bad step cannot spin forever.
        while iterations < FeedManager.chunkWalkLimit {
            iterations += 1
            guard let earlier = (try? database.earliestArticleDate(before: cursor)) ?? nil else {
                return nil
            }
            let chunkStart = FeedManager.chunkStart(for: earlier)
            guard chunkStart < cursor else { return nil }
            let chunkEnd = FeedManager.chunkEnd(for: chunkStart)
            let chunkArticles = (try? database.allArticles(from: chunkStart, to: chunkEnd, limit: 10000)) ?? []
            var visible = muted.isEmpty ? chunkArticles : chunkArticles.filter { !muted.contains($0.feedID) }
            visible = applyAllRules(visible)
            if !visible.isEmpty {
                return chunkStart
            }
            cursor = chunkStart
        }
        return nil
    }

    // MARK: - Read / Bookmark State

    func markRead(_ article: Article) {
        try? database.markArticleRead(id: article.id, read: true)
        try? database.updateLastAccessed(articleID: article.id)
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
        return unreadCounts[feed.id] ?? 0
    }

    func totalUnreadCount() -> Int {
        _ = dataRevision
        let muted = mutedFeedIDs
        if muted.isEmpty {
            return unreadCounts.values.reduce(0, +)
        }
        return unreadCounts.filter { !muted.contains($0.key) }.values.reduce(0, +)
    }

    // MARK: - Recently Accessed

    func recentlyAccessedArticles() -> [Article] {
        (try? database.recentlyAccessedArticles()) ?? []
    }

    func clearAccessHistory() {
        try? database.clearAccessHistory()
        loadFromDatabase()
    }

    // MARK: - Section Queries

    func todayArticles(for section: FeedSection) -> [Article] {
        let sectionFeedIDs = Set(feeds.filter { $0.feedSection == section }.map(\.id))
        return todayArticles().filter { sectionFeedIDs.contains($0.feedID) }
    }

    func olderArticles(for section: FeedSection, limit: Int = 200) -> [Article] {
        let sectionFeedIDs = Set(feeds.filter { $0.feedSection == section }.map(\.id))
        return olderArticles(limit: limit).filter { sectionFeedIDs.contains($0.feedID) }
    }

    func articles(for section: FeedSection, since date: Date) -> [Article] {
        let sectionFeedIDs = Set(feeds.filter { $0.feedSection == section }.map(\.id))
        return articles(since: date).filter { sectionFeedIDs.contains($0.feedID) }
    }

    func nextArticleChunk(for section: FeedSection, before date: Date) -> Date? {
        let sectionFeedIDs = Set(feeds.filter { $0.feedSection == section }.map(\.id))
        guard !sectionFeedIDs.isEmpty else { return nil }
        let muted = mutedFeedIDs
        var cursor = date
        var iterations = 0
        while iterations < FeedManager.chunkWalkLimit {
            iterations += 1
            guard let chunkStart = nextArticleChunk(before: cursor) else { return nil }
            guard chunkStart < cursor else { return nil }
            let chunkEnd = FeedManager.chunkEnd(for: chunkStart)
            let chunkArticles = (try? database.allArticles(from: chunkStart, to: chunkEnd, limit: 10000)) ?? []
            var visible = muted.isEmpty ? chunkArticles : chunkArticles.filter { !muted.contains($0.feedID) }
            visible = applyAllRules(visible).filter { sectionFeedIDs.contains($0.feedID) }
            if !visible.isEmpty {
                return chunkStart
            }
            cursor = chunkStart
        }
        return nil
    }

    func markAllRead(for section: FeedSection) {
        let sectionFeeds = feeds.filter { $0.feedSection == section }
        for feed in sectionFeeds {
            try? database.markAllRead(feedID: feed.id)
        }
        loadFromDatabase()
        updateBadgeCount()
    }

    func unreadCount(for section: FeedSection) -> Int {
        _ = dataRevision
        let sectionFeedIDs = Set(feeds.filter { $0.feedSection == section && !$0.isMuted }.map(\.id))
        return unreadCounts.filter { sectionFeedIDs.contains($0.key) }.values.reduce(0, +)
    }

    func hasFeeds(for section: FeedSection) -> Bool {
        _ = dataRevision
        return feeds.contains { $0.feedSection == section }
    }

    // MARK: - Filtering Helpers

    private func filterExcludingPodcastsAndVideos(_ articles: [Article]) -> [Article] {
        let excludedFeedIDs = Set(feeds.filter { feed in
            feed.isMuted || feed.isPodcast || DisplayStyleVideoDomains.shouldPreferVideo(feedDomain: feed.domain)
        }.map(\.id))
        return articles.filter { !excludedFeedIDs.contains($0.feedID) }
    }
}
