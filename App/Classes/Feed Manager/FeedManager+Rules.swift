import Foundation

extension FeedManager {

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
        let allArticles = (try? database.articles(forFeedID: feed.id)) ?? []
        var seen = Set<String>()
        var result: [String] = []
        for article in allArticles {
            if let author = article.author, !author.isEmpty, seen.insert(author).inserted {
                result.append(author)
            }
        }
        return result
    }

    // MARK: - Rule Application

    func applyRules(_ articles: [Article], feedID: Int64) -> [Article] {
        let filtered = Self.applyRules(articles, feedID: feedID, database: database)
        return applyContentOverrides(filtered, feedID: feedID)
    }

    nonisolated static func applyRules(_ articles: [Article], feedID: Int64, database: DatabaseManager) -> [Article] {
        let allowedKeywords = (try? database.rules(forFeedID: feedID, type: "allowed_keyword")) ?? []
        let keywords = (try? database.rules(forFeedID: feedID, type: "muted_keyword")) ?? []
        let authors = Set((try? database.rules(forFeedID: feedID, type: "muted_author")) ?? [])
        guard !allowedKeywords.isEmpty || !keywords.isEmpty || !authors.isEmpty else { return articles }
        return articles.filter { article in
            if !allowedKeywords.isEmpty {
                return Self.articleMatchesKeywords(article, keywords: allowedKeywords)
            }
            if let author = article.author, authors.contains(author) {
                return false
            }
            for keyword in keywords {
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

    /// Adjusts raw per-feed unread counts so muted articles (by keyword or
    /// author rules) are excluded. Only feeds with rules are recomputed.
    nonisolated static func applyRulesToUnreadCounts(_ rawCounts: [Int64: Int], database: DatabaseManager) -> [Int64: Int] {
        let feedsWithRules = (try? database.feedIDsWithRules()) ?? []
        guard !feedsWithRules.isEmpty else { return rawCounts }
        var result = rawCounts
        for feedID in feedsWithRules where (result[feedID] ?? 0) > 0 {
            let unread = (try? database.unreadArticles(forFeedID: feedID)) ?? []
            result[feedID] = applyRules(unread, feedID: feedID, database: database).count
        }
        return result
    }

    func applyAllRules(_ articles: [Article]) -> [Article] {
        // swiftlint:disable:next large_tuple
        var rulesByFeed: [Int64: (allowedKeywords: [String], keywords: [String], authors: Set<String>)] = [:]
        var result: [Article] = []
        for article in articles {
            if rulesByFeed[article.feedID] == nil {
                let allowedKeywords = (try? database.rules(forFeedID: article.feedID, type: "allowed_keyword")) ?? []
                let keywords = (try? database.rules(forFeedID: article.feedID, type: "muted_keyword")) ?? []
                let authors = Set((try? database.rules(forFeedID: article.feedID, type: "muted_author")) ?? [])
                rulesByFeed[article.feedID] = (allowedKeywords, keywords, authors)
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
        return applyContentOverrides(result)
    }

    private func articleMatchesKeywords(_ article: Article, keywords: [String]) -> Bool {
        Self.articleMatchesKeywords(article, keywords: keywords)
    }

    nonisolated fileprivate static func articleMatchesKeywords(_ article: Article, keywords: [String]) -> Bool {
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
