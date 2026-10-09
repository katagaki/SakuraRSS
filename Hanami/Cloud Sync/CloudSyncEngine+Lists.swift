import CloudKit
import Foundation

nonisolated extension CloudSyncEngine {

    static let listRuleFieldKeys = [
        "allowed_keyword": "allowedKeywords",
        "muted_keyword": "mutedKeywords",
        "muted_author": "mutedAuthors"
    ]

    static var listFieldKeys: [CKRecord.FieldKey] {
        ["name", "icon", "displayStyle", "sortOrder", "memberFeedSyncIDs", "userModifiedAt"]
            + listRuleFieldKeys.values
    }

    // MARK: - Local → CKRecord

    func record(forListSyncID syncID: String) -> CKRecord? {
        guard let list = try? database.syncedList(bySyncID: syncID) else { return nil }
        let record = archivedRecord(syncID: syncID)
            ?? CKRecord(recordType: Self.listRecordType, recordID: Self.recordID(for: syncID))
        record["name"] = list.name
        record["icon"] = list.icon
        record["displayStyle"] = list.displayStyle
        record["sortOrder"] = list.sortOrder
        record["memberFeedSyncIDs"] = list.memberFeedSyncIDs
        for (ruleType, fieldKey) in Self.listRuleFieldKeys {
            record[fieldKey] = list.rules[ruleType] ?? []
        }
        record["userModifiedAt"] = list.userModifiedAt
        return record
    }

    // MARK: - CKRecord → Local

    func syncedList(from record: CKRecord) -> SyncedList? {
        guard let name = record["name"] as? String, !name.isEmpty else { return nil }
        var rules: [String: [String]] = [:]
        for (ruleType, fieldKey) in Self.listRuleFieldKeys {
            rules[ruleType] = record[fieldKey] as? [String] ?? []
        }
        return SyncedList(
            syncID: record.recordID.recordName,
            name: name,
            icon: record["icon"] as? String ?? "newspaper",
            displayStyle: record["displayStyle"] as? String,
            sortOrder: record["sortOrder"] as? Int ?? 0,
            memberFeedSyncIDs: record["memberFeedSyncIDs"] as? [String] ?? [],
            rules: rules,
            userModifiedAt: record["userModifiedAt"] as? Date
        )
    }

    func applyFetchedList(_ record: CKRecord, tombstoneIDs: Set<String>? = nil) {
        guard let synced = syncedList(from: record) else { return }
        let tombstones = tombstoneIDs ?? Set((try? database.allSyncTombstoneIDs()) ?? [])
        if tombstones.contains(synced.syncID) { return }
        do {
            let outcome = try database.applySyncedList(synced)
            if case .merged = outcome {
                engine?.state.add(pendingRecordZoneChanges: [.saveRecord(Self.recordID(for: synced.syncID))])
            }
        } catch {
            log("CloudSyncEngine", "Failed to apply list \(synced.syncID): \(error)")
        }
    }

    /// Remote deletions skip the tombstone so they don't echo back.
    func applyRemoteListDeletion(syncID: String) {
        try? database.removeSyncTombstone(syncID: syncID)
        _ = try? database.deleteList(bySyncID: syncID)
    }

    // MARK: - Upgrades

    /// Lists made before list sync existed get their sync IDs here, even
    /// when the engine resumes from saved state and skips the initial sync.
    func enqueueUnsyncedLists(on engine: CKSyncEngine) {
        let assignedSyncIDs = (try? database.backfillListSyncIDs()) ?? []
        guard !assignedSyncIDs.isEmpty else { return }
        engine.state.add(pendingRecordZoneChanges: assignedSyncIDs.map { .saveRecord(Self.recordID(for: $0)) })
        log("CloudSyncEngine", "Enqueued \(assignedSyncIDs.count) unsynced lists")
    }

    /// An older version on this device fetched other devices' List records
    /// and dropped them while advancing the change token, so they'd never
    /// arrive again. Re-reads the zone once to pick them up.
    func catchUpListsIfNeeded(startedFresh: Bool) {
        guard !UserDefaults.standard.bool(forKey: Self.didCatchUpListsKey) else { return }
        if startedFresh {
            UserDefaults.standard.set(true, forKey: Self.didCatchUpListsKey)
            return
        }
        Task.detached(priority: .utility) { [weak self] in
            await self?.catchUpLists()
        }
    }

    private func catchUpLists() async {
        guard let listRecords = await fetchAllRecords(
            ofType: Self.listRecordType, desiredKeys: Self.listFieldKeys
        ) else { return }
        if !listRecords.isEmpty {
            archiveSystemFields(of: listRecords)
            let tombstoneIDs = Set((try? database.allSyncTombstoneIDs()) ?? [])
            for record in listRecords {
                applyFetchedList(record, tombstoneIDs: tombstoneIDs)
            }
            try? database.resolvePendingListMembers()
            onRemoteChangesApplied?(false)
        }
        UserDefaults.standard.set(true, forKey: Self.didCatchUpListsKey)
        log("CloudSyncEngine", "List catch-up applied \(listRecords.count) lists")
    }

    /// Reads the whole zone, outside the engine's change token, for record
    /// types an older version fetched and dropped. Returns nil on failure.
    func fetchAllRecords(
        ofType recordType: CKRecord.RecordType,
        desiredKeys: [CKRecord.FieldKey]
    ) async -> [CKRecord]? {
        let cloudDatabase = CKContainer(identifier: Self.containerIdentifier).privateCloudDatabase
        var records: [CKRecord] = []
        var changeToken: CKServerChangeToken?
        var moreComing = true
        do {
            while moreComing {
                let changes = try await cloudDatabase.recordZoneChanges(
                    inZoneWith: Self.zoneID, since: changeToken, desiredKeys: desiredKeys
                )
                records += changes.modificationResultsByID.values
                    .compactMap { try? $0.get().record }
                    .filter { $0.recordType == recordType }
                changeToken = changes.changeToken
                moreComing = changes.moreComing
            }
        } catch let error as CKError where error.code == .zoneNotFound {
            return []
        } catch {
            log("CloudSyncEngine", "Catch-up for \(recordType) failed: \(error.localizedDescription)")
            return nil
        }
        return records
    }
}
