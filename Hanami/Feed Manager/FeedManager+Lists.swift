import Foundation

public extension FeedManager {

    // MARK: - List CRUD

    @discardableResult
    func createList(name: String, icon: String) throws -> Int64 {
        let sortOrder = lists.count
        let newID = try database.insertList(name: name, icon: icon, sortOrder: sortOrder)
        captureUserListEdit(listID: newID)
        loadFromDatabase()
        return newID
    }

    func updateList(_ list: FeedList, name: String, icon: String, displayStyle: String?) {
        try? database.updateList(id: list.id, name: name, icon: icon, displayStyle: displayStyle)
        captureUserListEdit(listID: list.id)
        loadFromDatabase()
    }

    func deleteList(_ list: FeedList) {
        let syncID = database.listSyncID(forListID: list.id)
        try? database.deleteList(id: list.id)
        captureUserListDeletion(syncID: syncID)
        loadFromDatabase()
    }

    func reorderLists(_ reordered: [FeedList]) {
        let orders = reordered.enumerated().map { (id: $0.element.id, sortOrder: $0.offset) }
        try? database.updateListSortOrders(orders)
        let previousSortOrders = Dictionary(uniqueKeysWithValues: lists.map { ($0.id, $0.sortOrder) })
        for order in orders where previousSortOrders[order.id] != order.sortOrder {
            captureUserListEdit(listID: order.id)
        }
        loadFromDatabase()
    }

    // MARK: - List-Feed Membership

    func addFeedToList(_ list: FeedList, feed: Feed) {
        try? database.addFeedToList(listID: list.id, feedID: feed.id)
        captureUserListEdit(listID: list.id)
        loadFromDatabase()
    }

    func removeFeedFromList(_ list: FeedList, feed: Feed) {
        try? database.removeFeedFromList(listID: list.id, feedID: feed.id)
        captureUserListEdit(listID: list.id)
        loadFromDatabase()
    }

    func feeds(for list: FeedList) -> [Feed] {
        let ids = feedIDs(for: list)
        return feeds.filter { ids.contains($0.id) }
    }

    func feedIDs(for list: FeedList) -> Set<Int64> {
        listFeedIDs[list.id] ?? []
    }

    func feedCount(for list: FeedList) -> Int {
        listFeedIDs[list.id]?.count ?? 0
    }

    func listsContainingFeed(_ feed: Feed) -> [FeedList] {
        lists.filter { listFeedIDs[$0.id]?.contains(feed.id) ?? false }
    }

    func listIDsForFeed(_ feed: Feed) -> Set<Int64> {
        Set(listFeedIDs.compactMap { $0.value.contains(feed.id) ? $0.key : nil })
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
        let ids = feedIDs(for: list)
        return ids.reduce(0) { partial, feedID in
            partial + effectiveUnreadCount(forFeedID: feedID)
        }
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
        captureUserListEdit(listID: list.id)
    }

    func saveMutedKeywords(_ keywords: [String], for list: FeedList) {
        try? database.replaceListRules(listID: list.id, type: "muted_keyword", values: keywords)
        captureUserListEdit(listID: list.id)
    }

    func saveMutedAuthors(_ authors: [String], for list: FeedList) {
        try? database.replaceListRules(listID: list.id, type: "muted_author", values: authors)
        captureUserListEdit(listID: list.id)
    }

    func uniqueAuthorsInList(_ list: FeedList) -> [String] {
        let ids = feedIDs(for: list)
        guard !ids.isEmpty else { return [] }
        var seen = Set<String>()
        var result: [String] = []
        for feedID in ids {
            for author in (try? database.distinctAuthors(forFeedID: feedID)) ?? []
            where seen.insert(author).inserted {
                result.append(author)
            }
        }
        return result
    }

    // MARK: - List Rule Application

    func applyListRules(_ articles: [Article], listID: Int64) -> [Article] {
        Self.applyListRules(articles, listID: listID, database: database)
    }
}
