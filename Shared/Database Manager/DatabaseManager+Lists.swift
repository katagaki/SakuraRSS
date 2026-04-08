import Foundation
@preconcurrency import SQLite

nonisolated extension DatabaseManager {

    // MARK: - List CRUD

    @discardableResult
    func insertList(name: String, icon: String, displayStyle: String? = nil,
                    sortOrder: Int) throws -> Int64 {
        try database.run(lists.insert(
            listName <- name,
            listIcon <- icon,
            listDisplayStyle <- displayStyle,
            listSortOrder <- sortOrder
        ))
    }

    func allLists() throws -> [FeedList] {
        try database.prepare(lists.order(listSortOrder.asc, listName.asc)).map(rowToList)
    }

    func list(byID id: Int64) throws -> FeedList? {
        guard let row = try database.pluck(lists.filter(listID == id)) else { return nil }
        return rowToList(row)
    }

    func updateList(id: Int64, name: String, icon: String, displayStyle: String?) throws {
        let target = lists.filter(listID == id)
        try database.run(target.update(
            listName <- name,
            listIcon <- icon,
            listDisplayStyle <- displayStyle
        ))
    }

    func updateListSortOrders(_ orders: [(id: Int64, sortOrder: Int)]) throws {
        for entry in orders {
            let target = lists.filter(listID == entry.id)
            try database.run(target.update(listSortOrder <- entry.sortOrder))
        }
    }

    func deleteList(id: Int64) throws {
        try database.run(listFeeds.filter(listFeedListID == id).delete())
        try database.run(listRules.filter(listRuleListID == id).delete())
        try database.run(lists.filter(listID == id).delete())
    }

    // MARK: - List-Feed Membership

    func addFeedToList(listID lid: Int64, feedID fid: Int64) throws {
        try database.run(listFeeds.insert(
            or: .ignore,
            listFeedListID <- lid,
            listFeedFeedID <- fid
        ))
    }

    func removeFeedFromList(listID lid: Int64, feedID fid: Int64) throws {
        let target = listFeeds.filter(listFeedListID == lid && listFeedFeedID == fid)
        try database.run(target.delete())
    }

    func feedIDs(forListID lid: Int64) throws -> [Int64] {
        try database.prepare(
            listFeeds.filter(listFeedListID == lid).select(listFeedFeedID)
        ).map { $0[listFeedFeedID] }
    }

    func listIDs(forFeedID fid: Int64) throws -> [Int64] {
        try database.prepare(
            listFeeds.filter(listFeedFeedID == fid).select(listFeedListID)
        ).map { $0[listFeedListID] }
    }

    func feedCount(forListID lid: Int64) throws -> Int {
        try database.scalar(listFeeds.filter(listFeedListID == lid).count)
    }

    func listsContainingFeed(feedID fid: Int64) throws -> [FeedList] {
        let ids = try listIDs(forFeedID: fid)
        guard !ids.isEmpty else { return [] }
        return try database.prepare(
            lists.filter(ids.contains(listID)).order(listSortOrder.asc)
        ).map(rowToList)
    }

    // MARK: - List Rules CRUD

    func listRules(forListID lid: Int64, type: String) throws -> [String] {
        try database.prepare(
            listRules
                .filter(listRuleListID == lid && listRuleType == type)
                .order(listRuleValue.asc)
        ).map { $0[listRuleValue] }
    }

    func replaceListRules(listID lid: Int64, type: String, values: [String]) throws {
        let existing = listRules.filter(listRuleListID == lid && listRuleType == type)
        try database.run(existing.delete())
        for value in values {
            try database.run(listRules.insert(
                listRuleListID <- lid,
                listRuleType <- type,
                listRuleValue <- value
            ))
        }
    }

    func deleteAllListRules(forListID lid: Int64) throws {
        try database.run(listRules.filter(listRuleListID == lid).delete())
    }

    // MARK: - Cleanup on feed deletion

    func removeDeletedFeedFromLists(feedID fid: Int64) throws {
        try database.run(listFeeds.filter(listFeedFeedID == fid).delete())
    }

    // MARK: - Row Mapping

    func rowToList(_ row: Row) -> FeedList {
        FeedList(
            id: row[listID],
            name: row[listName],
            icon: row[listIcon],
            displayStyle: row[listDisplayStyle],
            sortOrder: row[listSortOrder]
        )
    }
}
