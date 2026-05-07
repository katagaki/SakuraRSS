import Foundation

extension FeedManager {

    // MARK: - Chunk Boundaries

    static var chunkWalkLimit: Int { 365 * 2 }

    /// Returns the 00:00-local chunk boundary at or before `date`.
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

    /// Articles published between local 12:00 and now, used for the
    /// Afternoon Brief summary card on the Today tab.
    func afternoonBriefArticles() -> [Article] {
        _ = dataRevision
        let calendar = Calendar.current
        let now = Date()
        let midnight = calendar.startOfDay(for: now)
        guard let noon = calendar.date(byAdding: .hour, value: 12, to: midnight) else {
            return []
        }
        let articles = (try? database.allArticles(from: noon, to: now)) ?? []
        return filterExcludingPodcastsAndVideos(articles)
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

    func articles(for feed: Feed, limit: Int? = nil, requireUnread: Bool = false) -> [Article] {
        _ = dataRevision
        guard requireUnread, let limit else {
            let all = (try? database.articles(forFeedID: feed.id, limit: limit)) ?? []
            return applyRules(all, feedID: feed.id)
        }
        var fetchLimit = max(limit * 4, 100)
        let maxIterations = 20
        for _ in 0..<maxIterations {
            let all = (try? database.articles(forFeedID: feed.id, limit: fetchLimit)) ?? []
            let pool = applyRules(all, feedID: feed.id)
            let unread = pool.filter { !$0.isRead }
            if unread.count >= limit || pool.count < fetchLimit {
                return Array(unread.prefix(limit))
            }
            fetchLimit *= 2
        }
        let all = (try? database.articles(forFeedID: feed.id, limit: fetchLimit)) ?? []
        return Array(applyRules(all, feedID: feed.id).filter { !$0.isRead }.prefix(limit))
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

    /// Most recent published date across the given feed IDs (e.g. all feeds
    /// in a section or list). Used to anchor the initial date-based batch
    /// window on the freshest content rather than wall-clock time.
    func latestPublishedDate(forFeedIDs feedIDs: Set<Int64>) -> Date? {
        _ = dataRevision
        return try? database.latestPublishedDate(forFeedIDs: feedIDs)
    }

    func latestPublishedDate() -> Date? {
        _ = dataRevision
        return try? database.latestPublishedDate()
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
        // Cursor must strictly decrease each iteration; cap guards against calendar edge cases.
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
        manualReadOverrides[article.id] = true
        try? database.markArticleRead(id: article.id, read: true)
        try? database.updateLastAccessed(articleID: article.id)
        loadFromDatabase()
        updateBadgeCount()
    }

    func toggleRead(_ article: Article) {
        let currentReadState = isRead(article)
        let newState = !currentReadState
        manualReadOverrides[article.id] = newState
        try? database.markArticleRead(id: article.id, read: newState)
        loadFromDatabase()
        updateBadgeCount()
    }

    func toggleBookmark(_ article: Article) {
        try? database.toggleBookmark(id: article.id)
        loadFromDatabase()
    }

    func markAllRead(feed: Feed) {
        manualReadOverrides.removeAll()
        try? database.markAllRead(feedID: feed.id)
        loadFromDatabase()
        updateBadgeCount()
    }

    func markAllRead() {
        manualReadOverrides.removeAll()
        try? database.markAllRead()
        loadFromDatabase()
        updateBadgeCount()
    }

    func markAllUnread() {
        manualReadOverrides.removeAll()
        try? database.markAllUnread()
        loadFromDatabase()
        updateBadgeCount()
    }

    func unreadCount(for feed: Feed) -> Int {
        _ = dataRevision
        return effectiveUnreadCount(forFeedID: feed.id)
    }

    func totalUnreadCount() -> Int {
        _ = dataRevision
        let muted = mutedFeedIDs
        return unreadCounts.keys.reduce(0) { partial, feedID in
            guard !muted.contains(feedID) else { return partial }
            return partial + effectiveUnreadCount(forFeedID: feedID)
        }
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
        _ = dataRevision
        let muted = mutedFeedIDs
        let sectionFeedIDs = Set(
            feeds
                .filter { $0.feedSection == section && !muted.contains($0.id) }
                .map(\.id)
        )
        guard !sectionFeedIDs.isEmpty else { return [] }
        let pool = (try? database.articles(forFeedIDs: sectionFeedIDs, since: date)) ?? []
        return applyAllRules(pool)
    }

    func undatedArticles(for section: FeedSection) -> [Article] {
        _ = dataRevision
        let muted = mutedFeedIDs
        let sectionFeedIDs = Set(
            feeds
                .filter { $0.feedSection == section && !muted.contains($0.id) }
                .map(\.id)
        )
        guard !sectionFeedIDs.isEmpty else { return [] }
        let pool = (try? database.undatedArticles(forFeedIDs: sectionFeedIDs)) ?? []
        return applyAllRules(pool)
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
        manualReadOverrides.removeAll()
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
        return sectionFeedIDs.reduce(0) { partial, feedID in
            partial + effectiveUnreadCount(forFeedID: feedID)
        }
    }

    func hasFeeds(for section: FeedSection) -> Bool {
        _ = dataRevision
        return feeds.contains { $0.feedSection == section }
    }

    // MARK: - Filtering Helpers

    private func filterExcludingPodcastsAndVideos(_ articles: [Article]) -> [Article] {
        let excludedFeedIDs = Set(feeds.filter { feed in
            feed.isMuted || feed.isPodcast || DisplayStyleSetDomains.style(for: feed.domain) == .video
        }.map(\.id))
        return articles.filter { !excludedFeedIDs.contains($0.feedID) }
    }
}
