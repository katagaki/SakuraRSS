import Foundation
@preconcurrency import SQLite

/// A feed record as it travels through CloudKit. Carries only fields that are
/// meaningful across devices; device-local state (icons, fetch timestamps,
/// Fediverse probe results) is re-derived on each device.
public nonisolated struct SyncedFeed: Sendable {
    public var syncID: String
    public var url: String
    public var title: String
    public var siteURL: String
    public var feedDescription: String
    public var iconURL: String?
    public var category: String?
    public var isPodcast: Bool
    public var isMuted: Bool
    public var isTitleCustomized: Bool
    public var userModifiedAt: Date?

    public init(syncID: String, url: String, title: String, siteURL: String,
                feedDescription: String, iconURL: String?, category: String?,
                isPodcast: Bool, isMuted: Bool, isTitleCustomized: Bool,
                userModifiedAt: Date?) {
        self.syncID = syncID
        self.url = url
        self.title = title
        self.siteURL = siteURL
        self.feedDescription = feedDescription
        self.iconURL = iconURL
        self.category = category
        self.isPodcast = isPodcast
        self.isMuted = isMuted
        self.isTitleCustomized = isTitleCustomized
        self.userModifiedAt = userModifiedAt
    }
}

public nonisolated extension DatabaseManager {

    // MARK: - Table Creation

    /// Adds the sync columns before creating the unique index so that
    /// existing databases upgrade safely even when the version-gated
    /// `fixup()` has not run yet.
    func createSyncTables() throws {
        _ = try? database.run(feeds.addColumn(feedSyncID))
        _ = try? database.run(feeds.addColumn(feedUserModifiedAt))
        try database.run(syncTombstones.create(ifNotExists: true) { table in
            table.column(tombstoneSyncID, primaryKey: true)
            table.column(tombstoneDeletedAt)
        })
        try database.run(syncState.create(ifNotExists: true) { table in
            table.column(syncStateKey, primaryKey: true)
            table.column(syncStateData)
        })
        _ = try? database.run(feeds.createIndex(feedSyncID, unique: true, ifNotExists: true))
    }

    // MARK: - Feed Sync Metadata

    func feed(bySyncID syncID: String) throws -> Feed? {
        guard let row = try database.pluck(feeds.filter(feedSyncID == syncID)) else { return nil }
        return rowToFeed(row)
    }

    func setFeedSyncID(feedID id: Int64, syncID: String) throws {
        let target = feeds.filter(feedID == id)
        try database.run(target.update(feedSyncID <- syncID))
    }

    func setFeedUserModifiedAt(feedID id: Int64, date: Date) throws {
        let target = feeds.filter(feedID == id)
        try database.run(target.update(feedUserModifiedAt <- date.timeIntervalSince1970))
    }

    func feedUserModifiedAt(syncID: String) -> Date? {
        guard let row = try? database.pluck(feeds.filter(feedSyncID == syncID)),
              let timestamp = try? row.get(feedUserModifiedAt) else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    /// Assigns a sync ID to every feed that lacks one and returns the
    /// newly assigned IDs.
    func backfillFeedSyncIDs() throws -> [String] {
        let rowsWithoutSyncID = try database.prepare(feeds.filter(feedSyncID == nil))
        var assignedSyncIDs: [String] = []
        for row in rowsWithoutSyncID {
            let newSyncID = UUID().uuidString
            let target = feeds.filter(feedID == row[feedID])
            try database.run(target.update(feedSyncID <- newSyncID))
            assignedSyncIDs.append(newSyncID)
        }
        return assignedSyncIDs
    }

    func allFeedSyncIDs() throws -> [String] {
        try database.prepare(feeds.select(feedSyncID)).compactMap { row in
            try? row.get(feedSyncID)
        }
    }

    // MARK: - Applying Remote Records

    /// Applies a feed record fetched from CloudKit. Matches by sync ID first,
    /// then by URL (adopting the incoming sync ID onto a feed the user also
    /// added locally). Returns the local feed ID and whether a row was inserted.
    @discardableResult
    func applySyncedFeed(_ synced: SyncedFeed) throws -> (feedID: Int64, inserted: Bool) {
        if let existing = try feed(bySyncID: synced.syncID) {
            try updateFeedFromSync(feedID: existing.id, synced: synced)
            return (existing.id, false)
        }
        if let existing = try feed(byURL: synced.url) {
            try setFeedSyncID(feedID: existing.id, syncID: synced.syncID)
            try updateFeedFromSync(feedID: existing.id, synced: synced)
            return (existing.id, false)
        }
        let insertedID = try database.run(feeds.insert(
            feedTitle <- synced.title,
            feedURL <- synced.url,
            feedSiteURL <- synced.siteURL,
            feedDescription <- synced.feedDescription,
            feedIconURL <- synced.iconURL,
            feedCategory <- synced.category,
            feedIsPodcast <- synced.isPodcast,
            feedIsMuted <- synced.isMuted,
            feedIsTitleCustomized <- synced.isTitleCustomized,
            feedSyncID <- synced.syncID,
            feedUserModifiedAt <- synced.userModifiedAt?.timeIntervalSince1970
        ))
        return (insertedID, true)
    }

    /// Skips the update when the local row has a newer user edit; the pending
    /// local change will win the conflict when it is sent to CloudKit.
    private func updateFeedFromSync(feedID id: Int64, synced: SyncedFeed) throws {
        if let localModifiedAt = feedUserModifiedAt(syncID: synced.syncID),
           let remoteModifiedAt = synced.userModifiedAt,
           localModifiedAt > remoteModifiedAt {
            return
        }
        let target = feeds.filter(feedID == id)
        try database.run(target.update(
            feedTitle <- synced.title,
            feedURL <- synced.url,
            feedSiteURL <- synced.siteURL,
            feedDescription <- synced.feedDescription,
            feedIconURL <- synced.iconURL,
            feedCategory <- synced.category,
            feedIsPodcast <- synced.isPodcast,
            feedIsMuted <- synced.isMuted,
            feedIsTitleCustomized <- synced.isTitleCustomized,
            feedUserModifiedAt <- synced.userModifiedAt?.timeIntervalSince1970
        ))
    }

    // MARK: - Tombstones

    func insertSyncTombstone(syncID: String, deletedAt: Date = Date()) throws {
        try database.run(syncTombstones.insert(
            or: .replace,
            tombstoneSyncID <- syncID,
            tombstoneDeletedAt <- deletedAt.timeIntervalSince1970
        ))
    }

    func removeSyncTombstone(syncID: String) throws {
        try database.run(syncTombstones.filter(tombstoneSyncID == syncID).delete())
    }

    func removeAllSyncTombstones() throws {
        try database.run(syncTombstones.delete())
    }

    func allSyncTombstoneIDs() throws -> [String] {
        try database.prepare(syncTombstones).map { row in
            row[tombstoneSyncID]
        }
    }

    // MARK: - Engine State

    func syncEngineStateData(forKey key: String) -> Data? {
        guard let row = try? database.pluck(syncState.filter(syncStateKey == key)) else { return nil }
        return try? row.get(syncStateData)
    }

    func setSyncEngineStateData(_ data: Data?, forKey key: String) {
        if let data {
            _ = try? database.run(syncState.insert(
                or: .replace,
                syncStateKey <- key,
                syncStateData <- data
            ))
        } else {
            _ = try? database.run(syncState.filter(syncStateKey == key).delete())
        }
    }
}
