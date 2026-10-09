import CloudKit
import Foundation

nonisolated extension CloudSyncEngine {

    static let pagePreferenceRecordType = "PagePreference"
    static let didCatchUpPagePreferencesKey = "iCloudSync.DidCatchUpPagePreferences"

    static func isPagePreferenceID(_ recordName: String) -> Bool {
        recordName.hasPrefix(DatabaseManager.pagePreferenceSyncIDPrefix)
    }

    // MARK: - Local → CKRecord

    func record(forPagePreferenceSyncID syncID: String) -> CKRecord? {
        guard let preference = try? database.pagePreference(bySyncID: syncID) else { return nil }
        let record = archivedRecord(syncID: syncID)
            ?? CKRecord(recordType: Self.pagePreferenceRecordType, recordID: Self.recordID(for: syncID))
        record["pageKey"] = preference.pageKey
        record["hidesReadContent"] = preference.hidesReadContent
        record["userModifiedAt"] = preference.userModifiedAt
        return record
    }

    // MARK: - CKRecord → Local

    func applyFetchedPagePreference(_ record: CKRecord) {
        guard let pageKey = record["pageKey"] as? String, !pageKey.isEmpty else { return }
        let synced = PagePreference(
            pageKey: pageKey,
            hidesReadContent: record["hidesReadContent"] as? Bool ?? false,
            userModifiedAt: record["userModifiedAt"] as? Date ?? .distantPast
        )
        do {
            try database.applySyncedPagePreference(synced)
        } catch {
            log("CloudSyncEngine", "Failed to apply page preference \(record.recordID.recordName): \(error)")
        }
    }

    func resolvePagePreferenceConflict(
        recordID: CKRecord.ID,
        serverRecord: CKRecord,
        syncEngine: CKSyncEngine
    ) {
        let serverModifiedAt = serverRecord["userModifiedAt"] as? Date ?? .distantPast
        let localModifiedAt = (try? database.pagePreference(bySyncID: recordID.recordName))?
            .userModifiedAt ?? .distantPast
        if localModifiedAt > serverModifiedAt {
            syncEngine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
        } else {
            applyFetchedPagePreference(serverRecord)
            onRemoteChangesApplied?(false)
        }
    }

    // MARK: - Change Notifications

    public func notePagePreferenceChanged() {
        enqueuePagePreferencesNeedingSync()
    }

    /// Changes made while the engine was off or still starting stay marked
    /// in SQLite and are picked up here when it starts.
    func enqueuePagePreferencesNeedingSync() {
        guard let engine else { return }
        let syncIDs = (try? database.pagePreferenceSyncIDsNeedingSync()) ?? []
        guard !syncIDs.isEmpty else { return }
        engine.state.add(pendingRecordZoneChanges: syncIDs.map { .saveRecord(Self.recordID(for: $0)) })
        try? database.clearPagePreferencesNeedSync(syncIDs: syncIDs)
    }

    // MARK: - Upgrades

    /// Older versions fetched PagePreference records and dropped them while
    /// advancing the change token, so they'd never arrive again.
    func catchUpPagePreferencesIfNeeded(startedFresh: Bool) {
        guard !UserDefaults.standard.bool(forKey: Self.didCatchUpPagePreferencesKey) else { return }
        if startedFresh {
            UserDefaults.standard.set(true, forKey: Self.didCatchUpPagePreferencesKey)
            return
        }
        Task.detached(priority: .utility) { [weak self] in
            await self?.catchUpPagePreferences()
        }
    }

    private func catchUpPagePreferences() async {
        guard let records = await fetchAllRecords(
            ofType: Self.pagePreferenceRecordType,
            desiredKeys: ["pageKey", "hidesReadContent", "userModifiedAt"]
        ) else { return }
        if !records.isEmpty {
            archiveSystemFields(of: records)
            for record in records {
                applyFetchedPagePreference(record)
            }
            onRemoteChangesApplied?(false)
        }
        UserDefaults.standard.set(true, forKey: Self.didCatchUpPagePreferencesKey)
    }
}
