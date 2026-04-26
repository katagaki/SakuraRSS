import Foundation

extension FeedManager {

    // MARK: - Count-based Batches (All)

    func articles(limit: Int) -> [Article] {
        _ = dataRevision
        let fetchLimit = max(limit * 4, 100)
        var all = (try? database.allArticles(limit: fetchLimit)) ?? []
        let muted = mutedFeedIDs
        if !muted.isEmpty {
            all = all.filter { !muted.contains($0.feedID) }
        }
        return Array(applyAllRules(all).prefix(limit))
    }

    func hasMoreArticles(beyond count: Int) -> Bool {
        _ = dataRevision
        let fetchLimit = count + max(count, 100)
        var all = (try? database.allArticles(limit: fetchLimit)) ?? []
        let muted = mutedFeedIDs
        if !muted.isEmpty {
            all = all.filter { !muted.contains($0.feedID) }
        }
        return applyAllRules(all).count > count
    }

    /// Walks forward in `batchSize` increments until the newly-revealed range
    /// contains at least one unread article. Returns nil when there is no
    /// further content to surface. With `requireUnread: false` any growth
    /// suffices, matching the simple `count + batchSize` increment.
    func nextLoadedCount(after count: Int, batchSize: Int, requireUnread: Bool = false) -> Int? {
        _ = dataRevision
        let maxIterations = 100
        var newCount = count + batchSize
        for _ in 0..<maxIterations {
            let revealedRange = self.articles(limit: newCount)
            guard revealedRange.count > count else { return nil }
            if !requireUnread {
                return newCount
            }
            if revealedRange.suffix(revealedRange.count - count).contains(where: { !$0.isRead }) {
                return newCount
            }
            newCount += batchSize
        }
        return nil
    }

    // MARK: - Count-based Batches (Section)

    func articles(for section: FeedSection, limit: Int) -> [Article] {
        let sectionFeedIDs = Set(feeds.filter { $0.feedSection == section }.map(\.id))
        guard !sectionFeedIDs.isEmpty else { return [] }
        return Array(articles(limit: limit * 3).filter { sectionFeedIDs.contains($0.feedID) }.prefix(limit))
    }

    func hasMoreArticles(for section: FeedSection, beyond count: Int) -> Bool {
        let sectionFeedIDs = Set(feeds.filter { $0.feedSection == section }.map(\.id))
        guard !sectionFeedIDs.isEmpty else { return false }
        let filtered = articles(limit: (count + 1) * 3).filter { sectionFeedIDs.contains($0.feedID) }
        return filtered.count > count
    }

    func nextLoadedCount(for section: FeedSection, after count: Int, batchSize: Int, requireUnread: Bool = false) -> Int? {
        let maxIterations = 100
        var newCount = count + batchSize
        for _ in 0..<maxIterations {
            let revealedRange = self.articles(for: section, limit: newCount)
            guard revealedRange.count > count else { return nil }
            if !requireUnread {
                return newCount
            }
            if revealedRange.suffix(revealedRange.count - count).contains(where: { !$0.isRead }) {
                return newCount
            }
            newCount += batchSize
        }
        return nil
    }

    // MARK: - Count-based Batches (Feed)

    func hasMoreArticles(for feed: Feed, beyond count: Int) -> Bool {
        _ = dataRevision
        let all = (try? database.articles(forFeedID: feed.id, limit: count + 1)) ?? []
        return applyRules(all, feedID: feed.id).count > count
    }

    func nextLoadedCount(for feed: Feed, after count: Int, batchSize: Int, requireUnread: Bool = false) -> Int? {
        _ = dataRevision
        let maxIterations = 100
        var newCount = count + batchSize
        for _ in 0..<maxIterations {
            let all = (try? database.articles(forFeedID: feed.id, limit: newCount)) ?? []
            let revealedRange = applyRules(all, feedID: feed.id)
            guard revealedRange.count > count else { return nil }
            if !requireUnread {
                return newCount
            }
            if revealedRange.suffix(revealedRange.count - count).contains(where: { !$0.isRead }) {
                return newCount
            }
            newCount += batchSize
        }
        return nil
    }

    // MARK: - Count-based Batches (List)

    func articles(for list: FeedList, limit: Int) -> [Article] {
        let listFeedIDs = feedIDs(for: list)
        guard !listFeedIDs.isEmpty else { return [] }
        let pooled = articles(limit: limit * 3).filter { listFeedIDs.contains($0.feedID) }
        return Array(applyListRules(pooled, listID: list.id).prefix(limit))
    }

    func hasMoreArticles(for list: FeedList, beyond count: Int) -> Bool {
        let listFeedIDs = feedIDs(for: list)
        guard !listFeedIDs.isEmpty else { return false }
        let pooled = articles(limit: (count + 1) * 3).filter { listFeedIDs.contains($0.feedID) }
        return applyListRules(pooled, listID: list.id).count > count
    }

    func nextLoadedCount(for list: FeedList, after count: Int, batchSize: Int, requireUnread: Bool = false) -> Int? {
        let maxIterations = 100
        var newCount = count + batchSize
        for _ in 0..<maxIterations {
            let revealedRange = self.articles(for: list, limit: newCount)
            guard revealedRange.count > count else { return nil }
            if !requireUnread {
                return newCount
            }
            if revealedRange.suffix(revealedRange.count - count).contains(where: { !$0.isRead }) {
                return newCount
            }
            newCount += batchSize
        }
        return nil
    }

    // MARK: - Date-based Batches (List)

    func articles(for list: FeedList, since date: Date) -> [Article] {
        let listFeedIDs = feedIDs(for: list)
        guard !listFeedIDs.isEmpty else { return [] }
        let filtered = articles(since: date).filter { listFeedIDs.contains($0.feedID) }
        return applyListRules(filtered, listID: list.id)
    }

    func nextArticleChunk(for list: FeedList, before date: Date, chunkDays days: Int, requireUnread: Bool = false) -> Date? {
        _ = dataRevision
        let listFeedIDs = feedIDs(for: list)
        guard !listFeedIDs.isEmpty else { return nil }
        let calendar = Calendar.current
        let muted = mutedFeedIDs
        var cursor = date
        var iterations = 0
        let maxIterations = FeedManager.chunkWalkLimit
        while iterations < maxIterations {
            iterations += 1
            guard (try? database.earliestArticleDate(before: cursor)) ?? nil != nil else { return nil }
            guard let newStart = calendar.date(byAdding: .day, value: -days, to: cursor) else { return nil }
            let windowArticles = (try? database.allArticles(from: newStart, to: cursor, limit: 10000)) ?? []
            var visible = muted.isEmpty ? windowArticles : windowArticles.filter { !muted.contains($0.feedID) }
            visible = applyAllRules(visible).filter { listFeedIDs.contains($0.feedID) }
            visible = applyListRules(visible, listID: list.id)
            if requireUnread {
                visible = visible.filter { !$0.isRead }
            }
            if !visible.isEmpty {
                return newStart
            }
            cursor = newStart
        }
        return nil
    }

    // MARK: - Date-based Batches (Arbitrary Window)

    /// Walks backwards in `chunkDays` windows until a visible-article window is
    /// found. When `requireUnread` is set, chunks with only-read articles are
    /// skipped so callers with Hide Viewed Content on don't dead-end on a
    /// chunk whose contents would be filtered out anyway.
    func nextArticleChunk(before date: Date, chunkDays days: Int, requireUnread: Bool = false) -> Date? {
        _ = dataRevision
        let calendar = Calendar.current
        let muted = mutedFeedIDs
        var cursor = date
        var iterations = 0
        let maxIterations = FeedManager.chunkWalkLimit
        while iterations < maxIterations {
            iterations += 1
            guard (try? database.earliestArticleDate(before: cursor)) ?? nil != nil else { return nil }
            guard let newStart = calendar.date(byAdding: .day, value: -days, to: cursor) else { return nil }
            let windowArticles = (try? database.allArticles(from: newStart, to: cursor, limit: 10000)) ?? []
            var visible = muted.isEmpty ? windowArticles : windowArticles.filter { !muted.contains($0.feedID) }
            visible = applyAllRules(visible)
            if requireUnread {
                visible = visible.filter { !$0.isRead }
            }
            if !visible.isEmpty {
                return newStart
            }
            cursor = newStart
        }
        return nil
    }

    func nextArticleChunk(for section: FeedSection, before date: Date, chunkDays days: Int, requireUnread: Bool = false) -> Date? {
        _ = dataRevision
        let sectionFeedIDs = Set(feeds.filter { $0.feedSection == section }.map(\.id))
        guard !sectionFeedIDs.isEmpty else { return nil }
        let calendar = Calendar.current
        let muted = mutedFeedIDs
        var cursor = date
        var iterations = 0
        let maxIterations = FeedManager.chunkWalkLimit
        while iterations < maxIterations {
            iterations += 1
            guard (try? database.earliestArticleDate(before: cursor)) ?? nil != nil else { return nil }
            guard let newStart = calendar.date(byAdding: .day, value: -days, to: cursor) else { return nil }
            let windowArticles = (try? database.allArticles(from: newStart, to: cursor, limit: 10000)) ?? []
            var visible = muted.isEmpty ? windowArticles : windowArticles.filter { !muted.contains($0.feedID) }
            visible = applyAllRules(visible).filter { sectionFeedIDs.contains($0.feedID) }
            if requireUnread {
                visible = visible.filter { !$0.isRead }
            }
            if !visible.isEmpty {
                return newStart
            }
            cursor = newStart
        }
        return nil
    }

    func nextArticleChunk(for feed: Feed, before date: Date, chunkDays days: Int, requireUnread: Bool = false) -> Date? {
        _ = dataRevision
        let calendar = Calendar.current
        var cursor = date
        var iterations = 0
        let maxIterations = FeedManager.chunkWalkLimit
        while iterations < maxIterations {
            iterations += 1
            guard (try? database.earliestArticleDate(forFeedID: feed.id, before: cursor)) ?? nil != nil else {
                return nil
            }
            guard let newStart = calendar.date(byAdding: .day, value: -days, to: cursor) else { return nil }
            let windowArticles = ((try? database.articles(forFeedID: feed.id, since: newStart)) ?? [])
                .filter { ($0.publishedDate ?? .distantPast) < cursor }
            var visible = applyRules(windowArticles, feedID: feed.id)
            if requireUnread {
                visible = visible.filter { !$0.isRead }
            }
            if !visible.isEmpty {
                return newStart
            }
            cursor = newStart
        }
        return nil
    }
}
