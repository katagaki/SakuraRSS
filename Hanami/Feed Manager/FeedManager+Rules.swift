import Foundation

public extension FeedManager {

    // MARK: - Feed Rules

    func allowedKeywords(for feed: Feed) -> [String] {
        (try? database.rules(forFeedID: feed.id, type: "allowed_keyword")) ?? []
    }

    func mutedKeywords(for feed: Feed) -> [String] {
        (try? database.rules(forFeedID: feed.id, type: "muted_keyword")) ?? []
    }

    func mutedAuthors(for feed: Feed) -> [String] {
        (try? database.rules(forFeedID: feed.id, type: "muted_author")) ?? []
    }

    func saveAllowedKeywords(_ keywords: [String], for feed: Feed) {
        try? database.replaceRules(feedID: feed.id, type: "allowed_keyword", values: keywords)
        loadFromDatabase()
        updateBadgeCount()
    }

    func saveMutedKeywords(_ keywords: [String], for feed: Feed) {
        try? database.replaceRules(feedID: feed.id, type: "muted_keyword", values: keywords)
        loadFromDatabase()
        updateBadgeCount()
    }

    func saveMutedAuthors(_ authors: [String], for feed: Feed) {
        try? database.replaceRules(feedID: feed.id, type: "muted_author", values: authors)
        loadFromDatabase()
        updateBadgeCount()
    }

    func uniqueAuthors(for feed: Feed) -> [String] {
        (try? database.distinctAuthors(forFeedID: feed.id)) ?? []
    }

    // MARK: - Rule Application

    func applyRules(_ articles: [Article], feedID: Int64) -> [Article] {
        let filtered = Self.applyRules(articles, feedID: feedID, database: database)
        return applyContentOverrides(filtered, feedID: feedID)
    }

    nonisolated static func applyRules(_ articles: [Article], feedID: Int64, database: DatabaseManager) -> [Article] {
        let rules = filterRules(forFeedID: feedID, database: database)
        return applyRules(articles, rules: rules)
    }

    nonisolated static func filterRules(forFeedID feedID: Int64, database: DatabaseManager) -> FeedFilterRules {
        FeedFilterRules(grouped: (try? database.allRules(forFeedID: feedID)) ?? [:])
    }

    /// Every feed's non-empty rules from a single query, keyed by feed ID.
    nonisolated static func allFilterRules(database: DatabaseManager) -> [Int64: FeedFilterRules] {
        let groupedByFeed = (try? database.allRulesByFeedID()) ?? [:]
        return groupedByFeed
            .mapValues(FeedFilterRules.init(grouped:))
            .filter { !$0.value.isEmpty }
    }

    nonisolated static func applyRules(_ articles: [Article], rules: FeedFilterRules) -> [Article] {
        guard !rules.isEmpty else { return articles }
        return articles.filter { passesRules($0, rules: rules) }
    }

    nonisolated static func passesRules(_ article: Article, rules: FeedFilterRules) -> Bool {
        if !rules.allowedKeywords.isEmpty {
            return articleMatchesKeywords(article, keywords: rules.allowedKeywords)
        }
        if let author = article.author, rules.authors.contains(author) {
            return false
        }
        return !articleMatchesKeywords(article, keywords: rules.keywords)
    }

    nonisolated static func applyRulesToUnreadCounts(
        _ rawCounts: [Int64: Int],
        database: DatabaseManager
    ) -> [Int64: Int] {
        let rulesByFeed = allFilterRules(database: database)
        guard !rulesByFeed.isEmpty else { return rawCounts }
        var result = rawCounts
        for (feedID, rules) in rulesByFeed where (result[feedID] ?? 0) > 0 {
            let unread = (try? database.unreadArticlesList(forFeedID: feedID)) ?? []
            result[feedID] = applyRules(unread, rules: rules).count
        }
        return result
    }

    func applyAllRules(_ articles: [Article]) -> [Article] {
        let filtered = Self.applyAllRules(articles, database: database)
        return applyContentOverrides(filtered)
    }

    nonisolated static func applyAllRules(_ articles: [Article], database: DatabaseManager) -> [Article] {
        applyAllRules(articles, rulesByFeed: allFilterRules(database: database))
    }

    nonisolated static func applyAllRules(
        _ articles: [Article],
        rulesByFeed: [Int64: FeedFilterRules]
    ) -> [Article] {
        guard !rulesByFeed.isEmpty else { return articles }
        return articles.filter { article in
            guard let rules = rulesByFeed[article.feedID] else { return true }
            return passesRules(article, rules: rules)
        }
    }

    nonisolated static func listFilterRules(listID: Int64, database: DatabaseManager) -> FeedFilterRules {
        FeedFilterRules(grouped: (try? database.allListRules(forListID: listID)) ?? [:])
    }

    nonisolated static func applyListRules(
        _ articles: [Article],
        listID: Int64,
        database: DatabaseManager
    ) -> [Article] {
        applyRules(articles, rules: listFilterRules(listID: listID, database: database))
    }

    private func articleMatchesKeywords(_ article: Article, keywords: [String]) -> Bool {
        Self.articleMatchesKeywords(article, keywords: keywords)
    }

    nonisolated static func articleMatchesKeywords(_ article: Article, keywords: [String]) -> Bool {
        for keyword in keywords {
            if article.title.localizedCaseInsensitiveContains(keyword) {
                return true
            }
            if let summary = article.summary,
               summary.localizedCaseInsensitiveContains(keyword) {
                return true
            }
        }
        return false
    }
}
