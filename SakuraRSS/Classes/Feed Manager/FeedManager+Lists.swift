import Foundation

extension FeedManager {

    // MARK: - List CRUD

    func createList(name: String, icon: String) throws {
        let sortOrder = lists.count
        try database.insertList(name: name, icon: icon, sortOrder: sortOrder)
        loadFromDatabase()
    }

    func updateList(_ list: FeedList, name: String, icon: String, displayStyle: String?) {
        try? database.updateList(id: list.id, name: name, icon: icon, displayStyle: displayStyle)
        loadFromDatabase()
    }

    func deleteList(_ list: FeedList) {
        try? database.deleteList(id: list.id)
        loadFromDatabase()
    }

    func reorderLists(_ reordered: [FeedList]) {
        let orders = reordered.enumerated().map { (id: $0.element.id, sortOrder: $0.offset) }
        try? database.updateListSortOrders(orders)
        loadFromDatabase()
    }

    // MARK: - List-Feed Membership

    func addFeedToList(_ list: FeedList, feed: Feed) {
        try? database.addFeedToList(listID: list.id, feedID: feed.id)
        loadFromDatabase()
    }

    func removeFeedFromList(_ list: FeedList, feed: Feed) {
        try? database.removeFeedFromList(listID: list.id, feedID: feed.id)
        loadFromDatabase()
    }

    func feeds(for list: FeedList) -> [Feed] {
        let ids = Set((try? database.feedIDs(forListID: list.id)) ?? [])
        return feeds.filter { ids.contains($0.id) }
    }

    func feedIDs(for list: FeedList) -> Set<Int64> {
        Set((try? database.feedIDs(forListID: list.id)) ?? [])
    }

    func feedCount(for list: FeedList) -> Int {
        (try? database.feedCount(forListID: list.id)) ?? 0
    }

    func listsContainingFeed(_ feed: Feed) -> [FeedList] {
        (try? database.listsContainingFeed(feedID: feed.id)) ?? []
    }

    func listIDsForFeed(_ feed: Feed) -> Set<Int64> {
        Set((try? database.listIDs(forFeedID: feed.id)) ?? [])
    }

    // MARK: - List Article Queries

    func todayArticles(for list: FeedList) -> [Article] {
        let listFeedIDs = feedIDs(for: list)
        guard !listFeedIDs.isEmpty else { return [] }
        let articles = todayArticles().filter { listFeedIDs.contains($0.feedID) }
        return applyListRules(articles, listID: list.id)
    }

    func olderArticles(for list: FeedList, limit: Int = 200) -> [Article] {
        let listFeedIDs = feedIDs(for: list)
        guard !listFeedIDs.isEmpty else { return [] }
        let articles = olderArticles(limit: limit).filter { listFeedIDs.contains($0.feedID) }
        return applyListRules(articles, listID: list.id)
    }

    func markAllRead(for list: FeedList) {
        let ids = feedIDs(for: list)
        for id in ids {
            try? database.markAllRead(feedID: id)
        }
        loadFromDatabase()
        updateBadgeCount()
    }

    func unreadCount(for list: FeedList) -> Int {
        _ = dataRevision
        let ids = feedIDs(for: list)
        return unreadCounts.filter { ids.contains($0.key) }.values.reduce(0, +)
    }

    // MARK: - List Rules

    func allowedKeywords(for list: FeedList) -> [String] {
        (try? database.listRules(forListID: list.id, type: "allowed_keyword")) ?? []
    }

    func mutedKeywords(for list: FeedList) -> [String] {
        (try? database.listRules(forListID: list.id, type: "muted_keyword")) ?? []
    }

    func mutedAuthors(for list: FeedList) -> [String] {
        (try? database.listRules(forListID: list.id, type: "muted_author")) ?? []
    }

    func saveAllowedKeywords(_ keywords: [String], for list: FeedList) {
        try? database.replaceListRules(listID: list.id, type: "allowed_keyword", values: keywords)
    }

    func saveMutedKeywords(_ keywords: [String], for list: FeedList) {
        try? database.replaceListRules(listID: list.id, type: "muted_keyword", values: keywords)
    }

    func saveMutedAuthors(_ authors: [String], for list: FeedList) {
        try? database.replaceListRules(listID: list.id, type: "muted_author", values: authors)
    }

    func uniqueAuthorsInList(_ list: FeedList) -> [String] {
        let ids = feedIDs(for: list)
        guard !ids.isEmpty else { return [] }
        var seen = Set<String>()
        var result: [String] = []
        for id in ids {
            let articles = (try? database.articles(forFeedID: id)) ?? []
            for article in articles {
                if let author = article.author, !author.isEmpty, seen.insert(author).inserted {
                    result.append(author)
                }
            }
        }
        return result
    }

    // MARK: - List Rule Application

    func applyListRules(_ articles: [Article], listID: Int64) -> [Article] {
        let allowedKeywords = (try? database.listRules(forListID: listID, type: "allowed_keyword")) ?? []
        let keywords = (try? database.listRules(forListID: listID, type: "muted_keyword")) ?? []
        let authors = Set((try? database.listRules(forListID: listID, type: "muted_author")) ?? [])
        guard !allowedKeywords.isEmpty || !keywords.isEmpty || !authors.isEmpty else { return articles }
        return articles.filter { article in
            if !allowedKeywords.isEmpty {
                return articleMatchesAnyKeyword(article, keywords: allowedKeywords)
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

    private func articleMatchesAnyKeyword(_ article: Article, keywords: [String]) -> Bool {
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
