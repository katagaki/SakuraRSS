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
        for modification in changes.modifications where modification.record.recordType == Self.feedRecordType {
            if applyFetchedRecord(modification.record) {
                insertedNewFeeds = true
            }
            appliedAnything = true
        }
        for deletion in changes.deletions {
            applyRemoteDeletion(recordID: deletion.recordID)
            appliedAnything = true
        }
        if appliedAnything {
            onRemoteChangesApplied?(insertedNewFeeds)
        }
    }

    /// Writes a fetched record into the local database. Returns `true`
    /// when a new feed row was inserted.
    @discardableResult
    func applyFetchedRecord(_ record: CKRecord) -> Bool {
        archiveSystemFields(of: record)
        guard let synced = syncedFeed(from: record) else { return false }
        // A tombstone means the user deleted this feed locally while the
        // remote edit was in flight; keep the deletion.
        let tombstoneIDs = (try? database.allSyncTombstoneIDs()) ?? []
        if tombstoneIDs.contains(synced.syncID) { return false }
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
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: archiver)
        archiver.finishEncoding()
        database.setSyncEngineStateData(
            archiver.encodedData,
            forKey: Self.archivedRecordKeyPrefix + record.recordID.recordName
        )
    }

    func archivedRecord(syncID: String) -> CKRecord? {
        guard let data = database.syncEngineStateData(forKey: Self.archivedRecordKeyPrefix + syncID),
              let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        unarchiver.requiresSecureCoding = true
        return CKRecord(coder: unarchiver)
    }
}
