import Foundation

/// Preloads the full ordered list of dated article IDs for a given scope so
/// views can apply the user's batching mode by slicing instead of repeatedly
/// re-querying the database with growing limits.
public extension FeedManager {

    /// Upper bound for the "all articles" preload. Far beyond what the list can
    /// be scrolled through, but keeps the whole articles table off the heap.
    nonisolated static var maximumPreloadedEntries: Int { 5000 }

    // MARK: - All Articles

    func preloadedArticleEntries(requireUnread: Bool = false) -> [ArticleIDEntry] {
        _ = dataRevision
        return Self.computeAllPreloadedEntries(
            database: database, muted: mutedFeedIDs, requireUnread: requireUnread
        )
    }

    // MARK: - Feed

    func preloadedArticleEntries(for feed: Feed, requireUnread: Bool = false) -> [ArticleIDEntry] {
        _ = dataRevision
        return Self.computeFeedPreloadedEntries(
            database: database, feedID: feed.id, requireUnread: requireUnread
        )
    }

    // MARK: - Section

    func preloadedArticleEntries(for section: FeedSection, requireUnread: Bool = false) -> [ArticleIDEntry] {
        _ = dataRevision
        let muted = mutedFeedIDs
        let sectionFeedIDs = feeds
            .filter { $0.feedSection == section && !muted.contains($0.id) }
            .map(\.id)
        return Self.computeSectionPreloadedEntries(
            database: database, feedIDs: sectionFeedIDs, requireUnread: requireUnread
        )
    }

    // MARK: - List

    /// Lists deliberately ignore the global feed-mute set so muted feeds still
    /// surface inside any list they belong to. Article-level rules (keywords,
    /// authors) and per-list rules still apply.
    func preloadedArticleEntries(for list: FeedList, requireUnread: Bool = false) -> [ArticleIDEntry] {
        _ = dataRevision
        return Self.computeListPreloadedEntries(
            database: database, feedIDs: Array(feedIDs(for: list)),
            listID: list.id, requireUnread: requireUnread
        )
    }

    // MARK: - Topic

    /// Preloads articles tagged with the given NLP entity name (a topic).
    /// Topics span all feeds, but global feed-mute and article-level rules
    /// still apply.
    func preloadedArticleEntries(forTopic topic: String, requireUnread: Bool = false) -> [ArticleIDEntry] {
        _ = dataRevision
        return Self.computeTopicPreloadedEntries(
            database: database, topic: topic, muted: mutedFeedIDs, requireUnread: requireUnread
        )
    }

    // MARK: - Materialization

    /// Materializes articles for the given preloaded IDs, preserving the
    /// preloaded order (which already reflects rule and mute filtering).
    func articles(withPreloadedIDs ids: [Int64]) -> [Article] {
        guard !ids.isEmpty else { return [] }
        _ = dataRevision
        let fetched = (try? database.articlesList(withIDs: ids)) ?? []
        let byID = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
        let ordered = ids.compactMap { byID[$0] }
        return applyContentOverrides(ordered)
    }

    // MARK: - Async Preload (Background)

    func preloadedArticleEntriesAsync(requireUnread: Bool = false) async -> [ArticleIDEntry] {
        let database = self.database
        let muted = mutedFeedIDs
        return await Task.detached {
            FeedManager.computeAllPreloadedEntries(
                database: database, muted: muted, requireUnread: requireUnread
            )
        }.value
    }

    func preloadedArticleEntriesAsync(
        for feed: Feed,
        requireUnread: Bool = false
    ) async -> [ArticleIDEntry] {
        let database = self.database
        let feedID = feed.id
        return await Task.detached {
            FeedManager.computeFeedPreloadedEntries(
                database: database, feedID: feedID, requireUnread: requireUnread
            )
        }.value
    }

    func preloadedArticleEntriesAsync(
        for section: FeedSection,
        requireUnread: Bool = false
    ) async -> [ArticleIDEntry] {
        let database = self.database
        let muted = mutedFeedIDs
        let sectionFeedIDs = feeds
            .filter { $0.feedSection == section && !muted.contains($0.id) }
            .map(\.id)
        return await Task.detached {
            FeedManager.computeSectionPreloadedEntries(
                database: database, feedIDs: sectionFeedIDs, requireUnread: requireUnread
            )
        }.value
    }

    func preloadedArticleEntriesAsync(
        for list: FeedList,
        requireUnread: Bool = false
    ) async -> [ArticleIDEntry] {
        let database = self.database
        let listFeedIDs = Array(feedIDs(for: list))
        let listID = list.id
        return await Task.detached {
            FeedManager.computeListPreloadedEntries(
                database: database, feedIDs: listFeedIDs,
                listID: listID, requireUnread: requireUnread
            )
        }.value
    }

    func preloadedArticleEntriesAsync(
        forTopic topic: String,
        requireUnread: Bool = false
    ) async -> [ArticleIDEntry] {
        let database = self.database
        let muted = mutedFeedIDs
        return await Task.detached {
            FeedManager.computeTopicPreloadedEntries(
                database: database, topic: topic,
                muted: muted, requireUnread: requireUnread
            )
        }.value
    }
}
