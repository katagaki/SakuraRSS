import Foundation
@preconcurrency import SQLite

nonisolated extension DatabaseManager {

    static let listSyncIDPrefix = "list."
    static let syncedListRuleTypes = ["allowed_keyword", "muted_keyword", "muted_author"]

    static func newListSyncID() -> String {
        listSyncIDPrefix + UUID().uuidString
    }

    // MARK: - Migration

    /// Runs on every launch for the same reason as `migrateBookmarkColumns()`.
    func migrateListSyncColumns() throws {
        let listColumns = try columnNames(ofTable: "lists")
        if !listColumns.contains("sync_id") {
            try database.run(lists.addColumn(listSyncID))
        }
        if !listColumns.contains("user_modified_at") {
            try database.run(lists.addColumn(listUserModifiedAt))
        }
        try database.run(lists.createIndex(listSyncID, unique: true, ifNotExists: true))
        try database.run(listPendingMembers.create(ifNotExists: true) { table in
            table.column(pendingMemberListSyncID)
            table.column(pendingMemberFeedSyncID)
            table.primaryKey(pendingMemberListSyncID, pendingMemberFeedSyncID)
        })
    }

    // MARK: - List Sync Metadata

    func listSyncID(forListID id: Int64) -> String? {
        guard let row = try? database.pluck(lists.filter(listID == id).select(listSyncID)) else { return nil }
        return (try? row.get(listSyncID)) ?? nil
    }

    func localListID(bySyncID syncID: String) -> Int64? {
        guard let row = try? database.pluck(lists.filter(listSyncID == syncID).select(listID)) else { return nil }
        return row[listID]
    }

    func setListUserModifiedAt(listID id: Int64, date: Date) throws {
        try database.run(lists.filter(listID == id).update(listUserModifiedAt <- date.timeIntervalSince1970))
    }

    func listUserModifiedAt(syncID: String) -> Date? {
        guard let row = try? database.pluck(lists.filter(listSyncID == syncID).select(listUserModifiedAt)),
              let timestamp = try? row.get(listUserModifiedAt) else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    func backfillListSyncIDs() throws -> [String] {
        var assignedSyncIDs: [String] = []
        for row in try database.prepare(lists.filter(listSyncID == nil).select(listID)) {
            let newSyncID = Self.newListSyncID()
            try database.run(lists.filter(listID == row[listID]).update(listSyncID <- newSyncID))
            assignedSyncIDs.append(newSyncID)
        }
        return assignedSyncIDs
    }

    func allListSyncIDs() throws -> [String] {
        try database.prepare(lists.select(listSyncID)).compactMap { row in
            (try? row.get(listSyncID)) ?? nil
        }
    }

    func syncedList(bySyncID syncID: String) throws -> SyncedList? {
        guard let row = try database.pluck(lists.filter(listSyncID == syncID)) else { return nil }
        let list = rowToList(row)
        let rules = try allListRules(forListID: list.id)
        return SyncedList(
            syncID: syncID,
            name: list.name,
            icon: list.icon,
            displayStyle: list.displayStyle,
            sortOrder: list.sortOrder,
            memberFeedSyncIDs: try memberFeedSyncIDs(forListID: list.id, listSyncID: syncID),
            rules: rules.filter { Self.syncedListRuleTypes.contains($0.key) },
            userModifiedAt: listUserModifiedAt(syncID: syncID)
        )
    }

    // MARK: - Membership by Feed Sync ID

    /// Local members plus remote members whose feeds haven't arrived yet, so
    /// re-uploading a list never drops members this device can't see.
    func memberFeedSyncIDs(forListID id: Int64, listSyncID syncID: String?) throws -> [String] {
        let localFeedIDs = try feedIDs(forListID: id)
        var memberSyncIDs = Set(try database.prepare(
            feeds.filter(localFeedIDs.contains(feedID)).select(feedSyncID)
        ).compactMap { (try? $0.get(feedSyncID)) ?? nil })
        if let syncID {
            memberSyncIDs.formUnion(try pendingMemberFeedSyncIDs(forListSyncID: syncID))
        }
        return memberSyncIDs.sorted()
    }

    func pendingMemberFeedSyncIDs(forListSyncID syncID: String) throws -> [String] {
        try database.prepare(
            listPendingMembers.filter(pendingMemberListSyncID == syncID)
        ).map { $0[pendingMemberFeedSyncID] }
    }

    func removePendingListMembers(listSyncID syncID: String) throws {
        try database.run(listPendingMembers.filter(pendingMemberListSyncID == syncID).delete())
    }

    func removePendingListMembers(feedSyncID syncID: String) throws {
        try database.run(listPendingMembers.filter(pendingMemberFeedSyncID == syncID).delete())
    }
}
