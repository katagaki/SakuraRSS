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

    // MARK: - Topic

    /// Preloads articles tagged with the given NLP entity name (a topic).
    /// Topics span all feeds, but global feed-mute and article-level rules
    /// still apply.
    func preloadedArticleEntries(forTopic topic: String, requireUnread: Bool = false) -> [ArticleIDEntry] {
        _ = dataRevision
        let muted = mutedFeedIDs
        let ids = (try? database.articleIDs(
            forEntity: topic,
            types: ["organization", "place"]
        )) ?? []
        let raw = (try? database.articles(withIDs: ids)) ?? []
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

    // MARK: - Async Preload (Background)

    /// Section/list switches in the Home tab kicked off the synchronous variants
    /// on the main thread, blocking the UI for the duration of the DB query and
    /// rule application. The async variants snapshot the main-actor state we
    /// need, then run the heavy DB and rule work on a detached task.
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

    // MARK: - Background computation helpers

    nonisolated static func computeAllPreloadedEntries(
        database: DatabaseManager,
        muted: Set<Int64>,
        requireUnread: Bool
    ) -> [ArticleIDEntry] {
        let raw = (try? database.allArticles(limit: Int.max)) ?? []
        var pool = applyAllRules(raw, database: database)
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

    nonisolated static func computeSectionPreloadedEntries(
        database: DatabaseManager,
        feedIDs: [Int64],
        requireUnread: Bool
    ) -> [ArticleIDEntry] {
        guard !feedIDs.isEmpty else { return [] }
        let raw = (try? database.articles(
            forFeedIDs: feedIDs,
            limit: Int.max,
            requireUnread: requireUnread
        )) ?? []
        return applyAllRules(raw, database: database).compactMap { article in
            guard let date = article.publishedDate else { return nil }
            return ArticleIDEntry(id: article.id, publishedDate: date)
        }
    }

    nonisolated static func computeListPreloadedEntries(
        database: DatabaseManager,
        feedIDs: [Int64],
        listID: Int64,
        requireUnread: Bool
    ) -> [ArticleIDEntry] {
        guard !feedIDs.isEmpty else { return [] }
        let raw = (try? database.articles(
            forFeedIDs: feedIDs,
            limit: Int.max,
            requireUnread: requireUnread
        )) ?? []
        let listed = applyListRules(
            applyAllRules(raw, database: database),
            listID: listID,
            database: database
        )
        return listed.compactMap { article in
            guard let date = article.publishedDate else { return nil }
            return ArticleIDEntry(id: article.id, publishedDate: date)
        }
    }

    nonisolated static func computeTopicPreloadedEntries(
        database: DatabaseManager,
        topic: String,
        muted: Set<Int64>,
        requireUnread: Bool
    ) -> [ArticleIDEntry] {
        let ids = (try? database.articleIDs(
            forEntity: topic,
            types: ["organization", "place"]
        )) ?? []
        let raw = (try? database.articles(withIDs: ids)) ?? []
        var pool = applyAllRules(raw, database: database)
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
}
