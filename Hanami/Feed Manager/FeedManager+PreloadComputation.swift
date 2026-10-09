import Foundation

/// Each preload takes an ID-only query when no rule applies to its feeds, and
/// only loads the text columns that rules match against when one does.
extension FeedManager {

    nonisolated static func computeAllPreloadedEntries(
        database: DatabaseManager,
        muted: Set<Int64>,
        requireUnread: Bool
    ) -> [ArticleIDEntry] {
        let rulesByFeed = allFilterRules(database: database).filter { !muted.contains($0.key) }
        guard !rulesByFeed.isEmpty else {
            return (try? database.articleIDEntries(
                excludingFeedIDs: muted,
                requireUnread: requireUnread,
                limit: FeedManager.maximumPreloadedEntries
            )) ?? []
        }
        let raw = (try? database.allArticlesList(limit: FeedManager.maximumPreloadedEntries)) ?? []
        var pool = applyAllRules(raw, rulesByFeed: rulesByFeed)
        if !muted.isEmpty {
            pool = pool.filter { !muted.contains($0.feedID) }
        }
        if requireUnread {
            pool = pool.filter { !$0.isRead }
        }
        return idEntries(from: pool)
    }

    nonisolated static func computeFeedPreloadedEntries(
        database: DatabaseManager,
        feedID: Int64,
        requireUnread: Bool
    ) -> [ArticleIDEntry] {
        let rules = filterRules(forFeedID: feedID, database: database)
        guard !rules.isEmpty else {
            return (try? database.articleIDEntries(feedIDs: [feedID], requireUnread: requireUnread)) ?? []
        }
        let raw = (try? database.articlesList(forFeedID: feedID)) ?? []
        var pool = applyRules(raw, rules: rules)
        if requireUnread {
            pool = pool.filter { !$0.isRead }
        }
        return idEntries(from: pool)
    }

    nonisolated static func computeSectionPreloadedEntries(
        database: DatabaseManager,
        feedIDs: [Int64],
        requireUnread: Bool
    ) -> [ArticleIDEntry] {
        guard !feedIDs.isEmpty else { return [] }
        let rulesByFeed = rules(for: feedIDs, database: database)
        guard !rulesByFeed.isEmpty else {
            return (try? database.articleIDEntries(feedIDs: feedIDs, requireUnread: requireUnread)) ?? []
        }
        let raw = (try? database.articlesList(
            forFeedIDs: feedIDs,
            limit: Int.max,
            requireUnread: requireUnread
        )) ?? []
        return idEntries(from: applyAllRules(raw, rulesByFeed: rulesByFeed))
    }

    nonisolated static func computeListPreloadedEntries(
        database: DatabaseManager,
        feedIDs: [Int64],
        listID: Int64,
        requireUnread: Bool
    ) -> [ArticleIDEntry] {
        guard !feedIDs.isEmpty else { return [] }
        let rulesByFeed = rules(for: feedIDs, database: database)
        let listRules = listFilterRules(listID: listID, database: database)
        guard !rulesByFeed.isEmpty || !listRules.isEmpty else {
            return (try? database.articleIDEntries(feedIDs: feedIDs, requireUnread: requireUnread)) ?? []
        }
        let raw = (try? database.articlesList(
            forFeedIDs: feedIDs,
            limit: Int.max,
            requireUnread: requireUnread
        )) ?? []
        let listed = applyRules(applyAllRules(raw, rulesByFeed: rulesByFeed), rules: listRules)
        return idEntries(from: listed)
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
        guard !ids.isEmpty else { return [] }
        let rulesByFeed = allFilterRules(database: database).filter { !muted.contains($0.key) }
        guard !rulesByFeed.isEmpty else {
            return (try? database.articleIDEntries(
                ids: ids,
                excludingFeedIDs: muted,
                requireUnread: requireUnread
            )) ?? []
        }
        let raw = (try? database.articlesList(withIDs: ids)) ?? []
        var pool = applyAllRules(raw, rulesByFeed: rulesByFeed)
        if !muted.isEmpty {
            pool = pool.filter { !muted.contains($0.feedID) }
        }
        if requireUnread {
            pool = pool.filter { !$0.isRead }
        }
        return idEntries(from: pool)
    }

    private nonisolated static func rules(
        for feedIDs: [Int64],
        database: DatabaseManager
    ) -> [Int64: FeedFilterRules] {
        let feedIDSet = Set(feedIDs)
        return allFilterRules(database: database).filter { feedIDSet.contains($0.key) }
    }

    private nonisolated static func idEntries(from articles: [Article]) -> [ArticleIDEntry] {
        articles.compactMap { article in
            guard let date = article.publishedDate else { return nil }
            return ArticleIDEntry(id: article.id, publishedDate: date)
        }
    }
}
