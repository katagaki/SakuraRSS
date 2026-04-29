import Foundation

extension FeedManager {

    // MARK: - Count-based Batches (All)

    func articles(limit: Int, requireUnread: Bool = false) -> [Article] {
        _ = dataRevision
        if !requireUnread {
            let fetchLimit = max(limit * 4, 100)
            var all = (try? database.allArticles(limit: fetchLimit)) ?? []
            let muted = mutedFeedIDs
            if !muted.isEmpty {
                all = all.filter { !muted.contains($0.feedID) }
            }
            return Array(applyAllRules(all).prefix(limit))
        }
        var fetchLimit = max(limit * 4, 100)
        let maxIterations = 20
        let muted = mutedFeedIDs
        for _ in 0..<maxIterations {
            var all = (try? database.allArticles(limit: fetchLimit)) ?? []
            if !muted.isEmpty {
                all = all.filter { !muted.contains($0.feedID) }
            }
            let pool = applyAllRules(all)
            let unread = pool.filter { !$0.isRead }
            if unread.count >= limit || pool.count < fetchLimit {
                return Array(unread.prefix(limit))
            }
            fetchLimit *= 2
        }
        var all = (try? database.allArticles(limit: fetchLimit)) ?? []
        if !muted.isEmpty {
            all = all.filter { !muted.contains($0.feedID) }
        }
        return Array(applyAllRules(all).filter { !$0.isRead }.prefix(limit))
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

    /// Returns the next loaded count, or nil if there's nothing more to reveal.
    func nextLoadedCount(after count: Int, batchSize: Int, requireUnread: Bool = false) -> Int? {
        _ = dataRevision
        let newCount = count + batchSize
        let revealedRange = self.articles(limit: newCount, requireUnread: requireUnread)
        guard revealedRange.count > count else { return nil }
        return newCount
    }

    // MARK: - Count-based Batches (Section)

    func articles(for section: FeedSection, limit: Int, requireUnread: Bool = false) -> [Article] {
        _ = dataRevision
        let sectionFeedIDs = sectionFeedIDsExcludingMuted(section)
        guard !sectionFeedIDs.isEmpty else { return [] }
        let feedIDList = Array(sectionFeedIDs)
        var fetchLimit = max(limit * 4, 100)
        let maxIterations = 20
        for _ in 0..<maxIterations {
            let raw = (try? database.articles(
                forFeedIDs: feedIDList,
                limit: fetchLimit,
                requireUnread: requireUnread
            )) ?? []
            let pool = applyAllRules(raw)
            if pool.count >= limit || raw.count < fetchLimit {
                return Array(pool.prefix(limit))
            }
            fetchLimit *= 2
        }
        let raw = (try? database.articles(
            forFeedIDs: feedIDList,
            limit: fetchLimit,
            requireUnread: requireUnread
        )) ?? []
        return Array(applyAllRules(raw).prefix(limit))
    }

    func hasMoreArticles(for section: FeedSection, beyond count: Int) -> Bool {
        _ = dataRevision
        let sectionFeedIDs = sectionFeedIDsExcludingMuted(section)
        guard !sectionFeedIDs.isEmpty else { return false }
        let feedIDList = Array(sectionFeedIDs)
        let pool = (try? database.articles(forFeedIDs: feedIDList, limit: count + 1)) ?? []
        return applyAllRules(pool).count > count
    }

    private func sectionFeedIDsExcludingMuted(_ section: FeedSection) -> Set<Int64> {
        let muted = mutedFeedIDs
        return Set(
            feeds
                .filter { $0.feedSection == section && !muted.contains($0.id) }
                .map(\.id)
        )
    }

    func nextLoadedCount(
        for section: FeedSection,
        after count: Int,
        batchSize: Int,
        requireUnread: Bool = false
    ) -> Int? {
        let newCount = count + batchSize
        let revealedRange = self.articles(for: section, limit: newCount, requireUnread: requireUnread)
        guard revealedRange.count > count else { return nil }
        return newCount
    }

    // MARK: - Count-based Batches (Feed)

    func hasMoreArticles(for feed: Feed, beyond count: Int) -> Bool {
        _ = dataRevision
        let all = (try? database.articles(forFeedID: feed.id, limit: count + 1)) ?? []
        return applyRules(all, feedID: feed.id).count > count
    }

    func nextLoadedCount(for feed: Feed, after count: Int, batchSize: Int, requireUnread: Bool = false) -> Int? {
        _ = dataRevision
        let newCount = count + batchSize
        let revealedRange = self.articles(for: feed, limit: newCount, requireUnread: requireUnread)
        guard revealedRange.count > count else { return nil }
        return newCount
    }

    // MARK: - Count-based Batches (List)

    func articles(for list: FeedList, limit: Int, requireUnread: Bool = false) -> [Article] {
        let listFeedIDs = feedIDs(for: list)
        guard !listFeedIDs.isEmpty else { return [] }
        var multiplier = 3
        let maxIterations = 20
        for _ in 0..<maxIterations {
            let pool = articles(limit: limit * multiplier)
            let pooled = pool.filter { listFeedIDs.contains($0.feedID) }
            let listed = applyListRules(pooled, listID: list.id)
            let candidates = requireUnread ? listed.filter { !$0.isRead } : listed
            if candidates.count >= limit || pool.count < limit * multiplier {
                return Array(candidates.prefix(limit))
            }
            multiplier *= 2
        }
        let pool = articles(limit: limit * multiplier)
        let pooled = pool.filter { listFeedIDs.contains($0.feedID) }
        let listed = applyListRules(pooled, listID: list.id)
        let candidates = requireUnread ? listed.filter { !$0.isRead } : listed
        return Array(candidates.prefix(limit))
    }

    func hasMoreArticles(for list: FeedList, beyond count: Int) -> Bool {
        let listFeedIDs = feedIDs(for: list)
        guard !listFeedIDs.isEmpty else { return false }
        let pooled = articles(limit: (count + 1) * 3).filter { listFeedIDs.contains($0.feedID) }
        return applyListRules(pooled, listID: list.id).count > count
    }

    func nextLoadedCount(for list: FeedList, after count: Int, batchSize: Int, requireUnread: Bool = false) -> Int? {
        let newCount = count + batchSize
        let revealedRange = self.articles(for: list, limit: newCount, requireUnread: requireUnread)
        guard revealedRange.count > count else { return nil }
        return newCount
    }

    // MARK: - Date-based Batches (List)

    func articles(for list: FeedList, since date: Date) -> [Article] {
        let listFeedIDs = feedIDs(for: list)
        guard !listFeedIDs.isEmpty else { return [] }
        let filtered = articles(since: date).filter { listFeedIDs.contains($0.feedID) }
        return applyListRules(filtered, listID: list.id)
    }

    func nextArticleChunk(
        for list: FeedList,
        before date: Date,
        chunkDays days: Int,
        requireUnread: Bool = false
    ) -> Date? {
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

    func nextArticleChunk(
        before date: Date,
        chunkDays days: Int,
        requireUnread: Bool = false
    ) -> Date? {
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

    func nextArticleChunk(
        for section: FeedSection,
        before date: Date,
        chunkDays days: Int,
        requireUnread: Bool = false
    ) -> Date? {
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

    func nextArticleChunk(
        for feed: Feed,
        before date: Date,
        chunkDays days: Int,
        requireUnread: Bool = false
    ) -> Date? {
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
