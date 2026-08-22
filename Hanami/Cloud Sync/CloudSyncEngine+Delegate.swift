import CloudKit
import Foundation

extension CloudSyncEngine: CKSyncEngineDelegate {

    public func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let stateUpdate):
            persistEngineState(stateUpdate.stateSerialization)
        case .accountChange(let accountChange):
            handleAccountChange(accountChange, syncEngine: syncEngine)
        case .fetchedDatabaseChanges(let changes):
            handleFetchedDatabaseChanges(changes, syncEngine: syncEngine)
        case .fetchedRecordZoneChanges(let changes):
            applyFetchedRecordZoneChanges(changes)
        case .sentRecordZoneChanges(let sent):
            handleSentRecordZoneChanges(sent, syncEngine: syncEngine)
        case .didFetchChanges:
            markSynced()
        case .didSendChanges:
            markSynced()
            // Drains the next chunk of any dirty-status backlog that was
            // held back by maxItemStatusEnqueuePerPass.
            noteItemStatusChanged()
        case .sentDatabaseChanges, .willFetchChanges, .willFetchRecordZoneChanges,
             .didFetchRecordZoneChanges, .willSendChanges:
            break
        @unknown default:
            break
        }
    }

    public func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let scope = context.options.scope
        let pendingChanges = syncEngine.state.pendingRecordZoneChanges.filter { scope.contains($0) }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pendingChanges) { recordID in
            let record: CKRecord?
            if Self.isItemStatusID(recordID.recordName) {
                record = self.record(forItemStatusSyncID: recordID.recordName)
            } else if let feed = try? self.database.feed(bySyncID: recordID.recordName) {
                record = self.record(for: feed)
            } else {
                record = nil
            }
            guard let record else {
                syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])
                return nil
            }
            return record
        }
    }

    // MARK: - Account Changes

    private func handleAccountChange(
        _ accountChange: CKSyncEngine.Event.AccountChange,
        syncEngine: CKSyncEngine
    ) {
        switch accountChange.changeType {
        case .signIn:
            queueInitialSync(on: syncEngine)
        case .signOut, .switchAccounts:
            // Local feeds stay; bookkeeping belongs to the previous account.
            clearSyncMetadata()
            queueInitialSync(on: syncEngine)
        @unknown default:
            break
        }
    }

    // MARK: - Database (Zone) Changes

    private func handleFetchedDatabaseChanges(
        _ changes: CKSyncEngine.Event.FetchedDatabaseChanges,
        syncEngine: CKSyncEngine
    ) {
        let zoneWasDeleted = changes.deletions.contains { deletion in
            deletion.zoneID.zoneName == Self.zoneName
        }
        if zoneWasDeleted {
            log("CloudSyncEngine", "Feed zone deleted remotely; re-uploading local feeds")
            clearSyncMetadata()
            queueInitialSync(on: syncEngine)
        }
    }

    // MARK: - Sent Changes

    private func handleSentRecordZoneChanges(
        _ sent: CKSyncEngine.Event.SentRecordZoneChanges,
        syncEngine: CKSyncEngine
    ) {
        archiveSystemFields(of: sent.savedRecords)
        for deletedRecordID in sent.deletedRecordIDs {
            try? database.removeSyncTombstone(syncID: deletedRecordID.recordName)
            database.setSyncEngineStateData(
                nil, forKey: Self.archivedRecordKeyPrefix + deletedRecordID.recordName
            )
        }
        for failedSave in sent.failedRecordSaves {
            handleFailedRecordSave(failedSave, syncEngine: syncEngine)
        }
        for (recordID, error) in sent.failedRecordDeletes {
            log("CloudSyncEngine", "Failed to delete record \(recordID.recordName): \(error.localizedDescription)")
            if error.code == .unknownItem {
                try? database.removeSyncTombstone(syncID: recordID.recordName)
            }
        }
    }

    private func handleFailedRecordSave(
        _ failedSave: CKSyncEngine.Event.SentRecordZoneChanges.FailedRecordSave,
        syncEngine: CKSyncEngine
    ) {
        let recordID = failedSave.record.recordID
        switch failedSave.error.code {
        case .serverRecordChanged:
            guard let serverRecord = failedSave.error.serverRecord else { return }
            resolveConflict(recordID: recordID, serverRecord: serverRecord, syncEngine: syncEngine)
        case .zoneNotFound:
            syncEngine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneName: Self.zoneName))])
            syncEngine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
        case .unknownItem:
            // The record vanished server-side; drop the stale change tag and re-create it.
            database.setSyncEngineStateData(nil, forKey: Self.archivedRecordKeyPrefix + recordID.recordName)
            syncEngine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
        default:
            // swiftlint:disable:next line_length
            log("CloudSyncEngine", "Failed to save record \(recordID.recordName): \(failedSave.error.localizedDescription)")
        }
    }

    /// Adopts the server's change tag either way; the side with the newer
    /// user edit supplies the field values.
    private func resolveConflict(
        recordID: CKRecord.ID,
        serverRecord: CKRecord,
        syncEngine: CKSyncEngine
    ) {
        archiveSystemFields(of: serverRecord)
        let syncID = recordID.recordName
        let serverModifiedAt = serverRecord["userModifiedAt"] as? Date ?? .distantPast

        if Self.isItemStatusID(syncID) {
            let localModifiedAt = (try? database.itemStatus(byStatusSyncID: syncID))
                .map { Date(timeIntervalSince1970: $0.modifiedAt) } ?? .distantPast
            if localModifiedAt > serverModifiedAt {
                syncEngine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
            } else {
                applyFetchedItemStatus(serverRecord)
                onRemoteChangesApplied?(false)
            }
            return
        }

        let localModifiedAt = database.feedUserModifiedAt(syncID: syncID) ?? .distantPast
        if localModifiedAt > serverModifiedAt {
            syncEngine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
        } else {
            let insertedNewFeeds = applyFetchedRecord(serverRecord)
            onRemoteChangesApplied?(insertedNewFeeds)
        }
    }
}
