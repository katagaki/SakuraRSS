import Foundation

/// Preloads the full ordered list of dated article IDs for a given scope so
/// views can apply the user's batching mode by slicing instead of repeatedly
/// re-querying the database with growing limits.
extension FeedManager {

    // MARK: - All Articles

    func preloadedArticleEntries(requireUnread: Bool = false) -> [ArticleIDEntry] {
        _ = dataRevision
        let muted = mutedFeedIDs
        let raw = (try? database.allArticles(limit: Int.max)) ?? []
        var pool = applyAllRules(raw)
        if !muted.isEmpty {
            pool = pool.filter { !muted.contains($0.feedID) }
        }
        if requireUnread {
            pool = pool.filter { !$0.isRead }
        }
        return pool.compactMap { article in
            guard let date = article.publishedDate else { return nil }
            return ArticleIDEntry(id: article.id, publishedDate: date)
        }
    }

    // MARK: - Feed

    func preloadedArticleEntries(for feed: Feed, requireUnread: Bool = false) -> [ArticleIDEntry] {
        _ = dataRevision
        let raw = (try? database.articles(forFeedID: feed.id)) ?? []
        var pool = applyRules(raw, feedID: feed.id)
        if requireUnread {
            pool = pool.filter { !$0.isRead }
        }
        return pool.compactMap { article in
            guard let date = article.publishedDate else { return nil }
            return ArticleIDEntry(id: article.id, publishedDate: date)
        }
    }

    // MARK: - Section

    func preloadedArticleEntries(for section: FeedSection, requireUnread: Bool = false) -> [ArticleIDEntry] {
        _ = dataRevision
        let muted = mutedFeedIDs
        let sectionFeedIDs = feeds
            .filter { $0.feedSection == section && !muted.contains($0.id) }
            .map(\.id)
        guard !sectionFeedIDs.isEmpty else { return [] }
        let raw = (try? database.articles(
            forFeedIDs: sectionFeedIDs,
            limit: Int.max,
            requireUnread: requireUnread
        )) ?? []
        return applyAllRules(raw).compactMap { article in
            guard let date = article.publishedDate else { return nil }
            return ArticleIDEntry(id: article.id, publishedDate: date)
        }
    }

    // MARK: - List

    /// Lists deliberately ignore the global feed-mute set so muted feeds still
    /// surface inside any list they belong to. Article-level rules (keywords,
    /// authors) and per-list rules still apply.
    func preloadedArticleEntries(for list: FeedList, requireUnread: Bool = false) -> [ArticleIDEntry] {
        _ = dataRevision
        let listFeedIDs = feedIDs(for: list)
        guard !listFeedIDs.isEmpty else { return [] }
        let raw = (try? database.articles(
            forFeedIDs: Array(listFeedIDs),
            limit: Int.max,
            requireUnread: requireUnread
        )) ?? []
        let listed = applyListRules(applyAllRules(raw), listID: list.id)
        return listed.compactMap { article in
            guard let date = article.publishedDate else { return nil }
            return ArticleIDEntry(id: article.id, publishedDate: date)
        }
    }

    // MARK: - Materialization

    /// Materializes articles for the given preloaded IDs, preserving the
    /// preloaded order (which already reflects rule and mute filtering).
    func articles(withPreloadedIDs ids: [Int64]) -> [Article] {
        guard !ids.isEmpty else { return [] }
        _ = dataRevision
        let fetched = (try? database.articles(withIDs: ids)) ?? []
        let byID = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
        let ordered = ids.compactMap { byID[$0] }
        return applyContentOverrides(ordered)
    }
}
