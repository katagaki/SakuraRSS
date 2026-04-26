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

    // MARK: - Count-based Batches (Feed)

    func hasMoreArticles(for feed: Feed, beyond count: Int) -> Bool {
        _ = dataRevision
        let all = (try? database.articles(forFeedID: feed.id, limit: count + 1)) ?? []
        return applyRules(all, feedID: feed.id).count > count
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

    // MARK: - Date-based Batches (List)

    func articles(for list: FeedList, since date: Date) -> [Article] {
        let listFeedIDs = feedIDs(for: list)
        guard !listFeedIDs.isEmpty else { return [] }
        let filtered = articles(since: date).filter { listFeedIDs.contains($0.feedID) }
        return applyListRules(filtered, listID: list.id)
    }

    func nextArticleChunk(for list: FeedList, before date: Date, chunkDays days: Int) -> Date? {
        _ = dataRevision
        let listFeedIDs = feedIDs(for: list)
        guard !listFeedIDs.isEmpty else { return nil }
        let calendar = Calendar.current
        guard (try? database.earliestArticleDate(before: date)) ?? nil != nil else { return nil }
        guard let newStart = calendar.date(byAdding: .day, value: -days, to: date) else { return nil }
        let muted = mutedFeedIDs
        let windowArticles = (try? database.allArticles(from: newStart, to: date, limit: 10000)) ?? []
        var visible = muted.isEmpty ? windowArticles : windowArticles.filter { !muted.contains($0.feedID) }
        visible = applyAllRules(visible).filter { listFeedIDs.contains($0.feedID) }
        visible = applyListRules(visible, listID: list.id)
        return visible.isEmpty ? nil : newStart
    }

    // MARK: - Date-based Batches (Arbitrary Window)

    /// Returns the start of the immediately preceding `chunkDays` window, or
    /// nil if that window has no visible articles. Stopping at the first empty
    /// window keeps the auto-load sentinel from skipping silently across long
    /// gaps when there is no new content to surface.
    func nextArticleChunk(before date: Date, chunkDays days: Int) -> Date? {
        _ = dataRevision
        let calendar = Calendar.current
        guard (try? database.earliestArticleDate(before: date)) ?? nil != nil else { return nil }
        guard let newStart = calendar.date(byAdding: .day, value: -days, to: date) else { return nil }
        let muted = mutedFeedIDs
        let windowArticles = (try? database.allArticles(from: newStart, to: date, limit: 10000)) ?? []
        var visible = muted.isEmpty ? windowArticles : windowArticles.filter { !muted.contains($0.feedID) }
        visible = applyAllRules(visible)
        return visible.isEmpty ? nil : newStart
    }

    func nextArticleChunk(for section: FeedSection, before date: Date, chunkDays days: Int) -> Date? {
        _ = dataRevision
        let sectionFeedIDs = Set(feeds.filter { $0.feedSection == section }.map(\.id))
        guard !sectionFeedIDs.isEmpty else { return nil }
        let calendar = Calendar.current
        guard (try? database.earliestArticleDate(before: date)) ?? nil != nil else { return nil }
        guard let newStart = calendar.date(byAdding: .day, value: -days, to: date) else { return nil }
        let muted = mutedFeedIDs
        let windowArticles = (try? database.allArticles(from: newStart, to: date, limit: 10000)) ?? []
        var visible = muted.isEmpty ? windowArticles : windowArticles.filter { !muted.contains($0.feedID) }
        visible = applyAllRules(visible).filter { sectionFeedIDs.contains($0.feedID) }
        return visible.isEmpty ? nil : newStart
    }

    func nextArticleChunk(for feed: Feed, before date: Date, chunkDays days: Int) -> Date? {
        _ = dataRevision
        let calendar = Calendar.current
        guard (try? database.earliestArticleDate(forFeedID: feed.id, before: date)) ?? nil != nil else {
            return nil
        }
        guard let newStart = calendar.date(byAdding: .day, value: -days, to: date) else { return nil }
        let windowArticles = ((try? database.articles(forFeedID: feed.id, since: newStart)) ?? [])
            .filter { ($0.publishedDate ?? .distantPast) < date }
        return applyRules(windowArticles, feedID: feed.id).isEmpty ? nil : newStart
    }
}
