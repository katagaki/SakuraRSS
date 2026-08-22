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
        let grouped = (try? database.allRules(forFeedID: feedID)) ?? [:]
        return FeedFilterRules(
            allowedKeywords: grouped["allowed_keyword"] ?? [],
            keywords: grouped["muted_keyword"] ?? [],
            authors: Set(grouped["muted_author"] ?? [])
        )
    }

    nonisolated static func applyRules(_ articles: [Article], rules: FeedFilterRules) -> [Article] {
        guard !rules.allowedKeywords.isEmpty || !rules.keywords.isEmpty || !rules.authors.isEmpty else {
            return articles
        }
        return articles.filter { article in
            if !rules.allowedKeywords.isEmpty {
                return articleMatchesKeywords(article, keywords: rules.allowedKeywords)
            }
            if let author = article.author, rules.authors.contains(author) {
                return false
            }
            for keyword in rules.keywords {
                if article.title.localizedCaseInsensitiveContains(keyword) {
                    return false
                }
                if let summary = article.summary,
                   summary.localizedCaseInsensitiveContains(keyword) {
                    return false
                }
            }
            return true
        }
    }

    nonisolated static func applyRulesToUnreadCounts(
        _ rawCounts: [Int64: Int],
        database: DatabaseManager
    ) -> [Int64: Int] {
        let feedsWithRules = (try? database.feedIDsWithRules()) ?? []
        guard !feedsWithRules.isEmpty else { return rawCounts }
        var result = rawCounts
        for feedID in feedsWithRules where (result[feedID] ?? 0) > 0 {
            let rules = filterRules(forFeedID: feedID, database: database)
            guard !rules.allowedKeywords.isEmpty || !rules.keywords.isEmpty || !rules.authors.isEmpty else {
                continue
            }
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
        var rulesByFeed: [Int64: FeedFilterRules] = [:]
        var result: [Article] = []
        for article in articles {
            if rulesByFeed[article.feedID] == nil {
                rulesByFeed[article.feedID] = filterRules(forFeedID: article.feedID, database: database)
            }
            let rules = rulesByFeed[article.feedID]!
            guard !rules.allowedKeywords.isEmpty || !rules.keywords.isEmpty || !rules.authors.isEmpty else {
                result.append(article)
                continue
            }
            if !rules.allowedKeywords.isEmpty {
                if articleMatchesKeywords(article, keywords: rules.allowedKeywords) {
                    result.append(article)
                }
                continue
            }
            if let author = article.author, rules.authors.contains(author) {
                continue
            }
            var matched = false
            for keyword in rules.keywords {
                if article.title.localizedCaseInsensitiveContains(keyword) {
                    matched = true
                    break
                }
                if let summary = article.summary,
                   summary.localizedCaseInsensitiveContains(keyword) {
                    matched = true
                    break
                }
            }
            if !matched {
                result.append(article)
            }
        }
        return result
    }

    nonisolated static func applyListRules(
        _ articles: [Article],
        listID: Int64,
        database: DatabaseManager
    ) -> [Article] {
        let grouped = (try? database.allListRules(forListID: listID)) ?? [:]
        let rules = FeedFilterRules(
            allowedKeywords: grouped["allowed_keyword"] ?? [],
            keywords: grouped["muted_keyword"] ?? [],
            authors: Set(grouped["muted_author"] ?? [])
        )
        return applyRules(articles, rules: rules)
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
