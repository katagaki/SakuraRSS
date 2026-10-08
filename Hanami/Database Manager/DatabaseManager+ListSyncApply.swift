import Foundation
@preconcurrency import SQLite

nonisolated extension DatabaseManager {

    // MARK: - Applying Remote Lists

    /// Matches by sync ID first, then by name (list names are unique per
    /// device), so a list the user recreated on another device before list
    /// sync existed merges instead of duplicating.
    func applySyncedList(_ synced: SyncedList) throws -> SyncedListApplyOutcome {
        if let localID = localListID(bySyncID: synced.syncID) {
            let localModifiedAt = listUserModifiedAt(syncID: synced.syncID) ?? .distantPast
            if localModifiedAt > (synced.userModifiedAt ?? .distantPast) { return .skipped }
            try database.transaction {
                try writeSyncedListFields(synced, listID: localID)
                try replaceListMembers(listID: localID, listSyncID: synced.syncID,
                                       memberFeedSyncIDs: synced.memberFeedSyncIDs)
            }
            return .applied
        }
        if let namesake = try allLists().first(where: {
            $0.name.localizedCaseInsensitiveCompare(synced.name) == .orderedSame
        }) {
            return try mergeSyncedList(synced, into: namesake)
        }
        try database.transaction {
            let insertedID = try database.run(lists.insert(
                listName <- synced.name,
                listIcon <- synced.icon,
                listSortOrder <- synced.sortOrder,
                listSyncID <- synced.syncID
            ))
            try writeSyncedListFields(synced, listID: insertedID)
            try replaceListMembers(listID: insertedID, listSyncID: synced.syncID,
                                   memberFeedSyncIDs: synced.memberFeedSyncIDs)
        }
        return .applied
    }

    /// Both devices pick the lexicographically smaller sync ID as the
    /// survivor, so they converge without deleting each other's list.
    private func mergeSyncedList(_ synced: SyncedList, into localList: FeedList) throws -> SyncedListApplyOutcome {
        let localSyncID = listSyncID(forListID: localList.id)
        let survivingSyncID = localSyncID.map { min($0, synced.syncID) } ?? synced.syncID
        let supersededSyncID = survivingSyncID == synced.syncID ? localSyncID : nil
        let localModifiedAt = localSyncID.flatMap(listUserModifiedAt(syncID:)) ?? .distantPast
        let remoteIsNewer = (synced.userModifiedAt ?? .distantPast) >= localModifiedAt
        let mergedMembers = Set(try memberFeedSyncIDs(forListID: localList.id, listSyncID: localSyncID))
            .union(synced.memberFeedSyncIDs)
        try database.transaction {
            if let supersededSyncID {
                try removePendingListMembers(listSyncID: supersededSyncID)
            }
            let target = lists.filter(listID == localList.id)
            try database.run(target.update(listSyncID <- survivingSyncID))
            if remoteIsNewer {
                try writeSyncedListFields(synced, listID: localList.id)
            }
            try database.run(target.update(listUserModifiedAt <- Date().timeIntervalSince1970))
            try replaceListMembers(listID: localList.id, listSyncID: survivingSyncID,
                                   memberFeedSyncIDs: Array(mergedMembers))
        }
        return .merged(survivingSyncID: survivingSyncID, supersededSyncID: supersededSyncID)
    }

    private func writeSyncedListFields(_ synced: SyncedList, listID id: Int64) throws {
        try database.run(lists.filter(listID == id).update(
            listName <- synced.name,
            listIcon <- synced.icon,
            listDisplayStyle <- synced.displayStyle,
            listSortOrder <- synced.sortOrder,
            listUserModifiedAt <- synced.userModifiedAt?.timeIntervalSince1970
        ))
        for ruleType in Self.syncedListRuleTypes {
            try replaceListRules(listID: id, type: ruleType, values: synced.rules[ruleType] ?? [])
        }
    }

    /// Members whose feeds haven't synced yet are parked in
    /// `list_pending_members` and attached by `resolvePendingListMembers()`.
    private func replaceListMembers(listID id: Int64, listSyncID syncID: String,
                                    memberFeedSyncIDs: [String]) throws {
        let tombstoneIDs = Set(try allSyncTombstoneIDs())
        try database.run(listFeeds.filter(listFeedListID == id).delete())
        try removePendingListMembers(listSyncID: syncID)
        for memberSyncID in Set(memberFeedSyncIDs) where !tombstoneIDs.contains(memberSyncID) {
            if let memberFeed = try feed(bySyncID: memberSyncID) {
                try addFeedToList(listID: id, feedID: memberFeed.id)
            } else {
                try database.run(listPendingMembers.insert(
                    or: .ignore,
                    pendingMemberListSyncID <- syncID,
                    pendingMemberFeedSyncID <- memberSyncID
                ))
            }
        }
    }

    /// Returns whether any list gained a member.
    @discardableResult
    func resolvePendingListMembers() throws -> Bool {
        let pendingRows = try database.prepare(listPendingMembers).map { row in
            (listSyncID: row[pendingMemberListSyncID], feedSyncID: row[pendingMemberFeedSyncID])
        }
        guard !pendingRows.isEmpty else { return false }
        let tombstoneIDs = Set(try allSyncTombstoneIDs())
        var resolvedAny = false
        try database.transaction {
            for pending in pendingRows {
                let pendingRow = listPendingMembers.filter(
                    pendingMemberListSyncID == pending.listSyncID && pendingMemberFeedSyncID == pending.feedSyncID
                )
                guard let localID = localListID(bySyncID: pending.listSyncID),
                      !tombstoneIDs.contains(pending.feedSyncID) else {
                    try database.run(pendingRow.delete())
                    continue
                }
                guard let memberFeed = try feed(bySyncID: pending.feedSyncID) else { continue }
                try addFeedToList(listID: localID, feedID: memberFeed.id)
                try database.run(pendingRow.delete())
                resolvedAny = true
            }
        }
        return resolvedAny
    }

    func deleteList(bySyncID syncID: String) throws -> Bool {
        guard let localID = localListID(bySyncID: syncID) else {
            try removePendingListMembers(listSyncID: syncID)
            return false
        }
        try deleteList(id: localID)
        return true
    }
}
