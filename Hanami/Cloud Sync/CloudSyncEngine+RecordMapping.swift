import CloudKit
import Foundation

nonisolated extension CloudSyncEngine {

    // MARK: - Local → CKRecord

    func record(for feed: Feed) -> CKRecord? {
        guard let syncID = feed.syncID else { return nil }
        let record = archivedRecord(syncID: syncID)
            ?? CKRecord(recordType: Self.feedRecordType, recordID: Self.recordID(for: syncID))
        record["url"] = feed.url
        record["title"] = feed.title
        record["siteURL"] = feed.siteURL
        record["feedDescription"] = feed.feedDescription
        record["iconURL"] = feed.iconURL
        record["category"] = feed.category
        record["isPodcast"] = feed.isPodcast
        record["isMuted"] = feed.isMuted
        record["isTitleCustomized"] = feed.isTitleCustomized
        record["userModifiedAt"] = database.feedUserModifiedAt(syncID: syncID)
        return record
    }

    func record(forItemStatusSyncID syncID: String) -> CKRecord? {
        guard let status = try? database.itemStatus(byStatusSyncID: syncID) else { return nil }
        let record = archivedRecord(syncID: syncID)
            ?? CKRecord(recordType: Self.itemStatusRecordType, recordID: Self.recordID(for: syncID))
        record["url"] = status.url
        record["isRead"] = status.isRead
        record["isBookmarked"] = status.isBookmarked
        record["userModifiedAt"] = Date(timeIntervalSince1970: status.modifiedAt)
        return record
    }

    // MARK: - CKRecord → Local

    func syncedFeed(from record: CKRecord) -> SyncedFeed? {
        guard let url = record["url"] as? String, !url.isEmpty else { return nil }
        return SyncedFeed(
            syncID: record.recordID.recordName,
            url: url,
            title: record["title"] as? String ?? url,
            siteURL: record["siteURL"] as? String ?? "",
            feedDescription: record["feedDescription"] as? String ?? "",
            iconURL: record["iconURL"] as? String,
            category: record["category"] as? String,
            isPodcast: record["isPodcast"] as? Bool ?? false,
            isMuted: record["isMuted"] as? Bool ?? false,
            isTitleCustomized: record["isTitleCustomized"] as? Bool ?? false,
            userModifiedAt: record["userModifiedAt"] as? Date
        )
    }

    // MARK: - Applying Fetched Changes

    func applyFetchedRecordZoneChanges(_ changes: CKSyncEngine.Event.FetchedRecordZoneChanges) {
        var insertedNewFeeds = false
        var appliedAnything = false
        archiveSystemFields(of: changes.modifications.map(\.record))
        let tombstoneIDs = Set((try? database.allSyncTombstoneIDs()) ?? [])
        for modification in changes.modifications {
            switch modification.record.recordType {
            case Self.feedRecordType:
                if applyFetchedRecord(modification.record, tombstoneIDs: tombstoneIDs) {
                    insertedNewFeeds = true
                }
                appliedAnything = true
            case Self.itemStatusRecordType:
                applyFetchedItemStatus(modification.record)
                appliedAnything = true
            default:
                break
            }
        }
        for deletion in changes.deletions {
            applyRemoteDeletion(recordID: deletion.recordID)
            appliedAnything = true
        }
        if appliedAnything {
            onRemoteChangesApplied?(insertedNewFeeds)
        }
    }

    func applyFetchedItemStatus(_ record: CKRecord) {
        guard let url = record["url"] as? String, !url.isEmpty else { return }
        let modifiedAt = (record["userModifiedAt"] as? Date)?.timeIntervalSince1970 ?? 0
        try? database.applyRemoteItemStatus(
            url: url,
            isRead: record["isRead"] as? Bool ?? false,
            isBookmarked: record["isBookmarked"] as? Bool ?? false,
            modifiedAt: modifiedAt,
            syncID: record.recordID.recordName
        )
    }

    @discardableResult
    func applyFetchedRecord(_ record: CKRecord, tombstoneIDs: Set<String>? = nil) -> Bool {
        guard let synced = syncedFeed(from: record) else { return false }
        // A tombstone means the user deleted this feed locally while the
        // remote edit was in flight; keep the deletion.
        let tombstones = tombstoneIDs ?? Set((try? database.allSyncTombstoneIDs()) ?? [])
        if tombstones.contains(synced.syncID) { return false }
        do {
            let result = try database.applySyncedFeed(synced)
            return result.inserted
        } catch {
            log("CloudSyncEngine", "Failed to apply record \(synced.syncID): \(error)")
            return false
        }
    }

    func applyRemoteDeletion(recordID: CKRecord.ID) {
        let syncID = recordID.recordName
        database.setSyncEngineStateData(nil, forKey: Self.archivedRecordKeyPrefix + syncID)
        // A deleted status record only clears sync bookkeeping (e.g. the other
        // device cleaned up an old item); the local read/bookmark state stays.
        if Self.isItemStatusID(syncID) { return }
        try? database.removeSyncTombstone(syncID: syncID)
        guard let feed = try? database.feed(bySyncID: syncID) else { return }
        if let onRemoteFeedDeleted {
            onRemoteFeedDeleted(feed)
        } else {
            try? database.deleteFeed(id: feed.id)
        }
    }

    // MARK: - System Field Archival

    /// Keeps each record's CloudKit change tag so re-saves don't conflict
    /// with our own previous uploads.
    func archiveSystemFields(of record: CKRecord) {
        database.setSyncEngineStateData(
            archivedSystemFields(of: record),
            forKey: Self.archivedRecordKeyPrefix + record.recordID.recordName
        )
    }

    func archiveSystemFields(of records: [CKRecord]) {
        guard !records.isEmpty else { return }
        database.setSyncEngineStateData(records.map { record in
            (key: Self.archivedRecordKeyPrefix + record.recordID.recordName,
             data: archivedSystemFields(of: record))
        })
    }

    private func archivedSystemFields(of record: CKRecord) -> Data {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: archiver)
        archiver.finishEncoding()
        return archiver.encodedData
    }

    func archivedRecord(syncID: String) -> CKRecord? {
        guard let data = database.syncEngineStateData(forKey: Self.archivedRecordKeyPrefix + syncID),
              let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        unarchiver.requiresSecureCoding = true
        return CKRecord(coder: unarchiver)
    }
}
