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
    }

    func saveMutedKeywords(_ keywords: [String], for feed: Feed) {
        try? database.replaceRules(feedID: feed.id, type: "muted_keyword", values: keywords)
    }

    func saveMutedAuthors(_ authors: [String], for feed: Feed) {
        try? database.replaceRules(feedID: feed.id, type: "muted_author", values: authors)
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
        let allowedKeywords = (try? database.rules(forFeedID: feedID, type: "allowed_keyword")) ?? []
        let keywords = (try? database.rules(forFeedID: feedID, type: "muted_keyword")) ?? []
        let authors = Set((try? database.rules(forFeedID: feedID, type: "muted_author")) ?? [])
        guard !keywords.isEmpty || !authors.isEmpty else { return articles }
        return articles.filter { article in
            if !allowedKeywords.isEmpty && articleMatchesKeywords(article, keywords: allowedKeywords) {
                return true
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

    func applyAllRules(_ articles: [Article]) -> [Article] {
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
            guard !rules.keywords.isEmpty || !rules.authors.isEmpty else {
                result.append(article)
                continue
            }
            if !rules.allowedKeywords.isEmpty && articleMatchesKeywords(article, keywords: rules.allowedKeywords) {
                result.append(article)
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

    private func articleMatchesKeywords(_ article: Article, keywords: [String]) -> Bool {
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
