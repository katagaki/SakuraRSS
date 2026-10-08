import Foundation
@preconcurrency import SQLite

/// Remote read/bookmark statuses for items this device hasn't fetched yet.
/// CKSyncEngine never redelivers a fetched record, so they're kept here and
/// applied when the item is inserted.
public nonisolated extension DatabaseManager {

    static let pendingItemStatusMaxAge: TimeInterval = 30 * 24 * 60 * 60
    static let pendingItemStatusMaxCount = 50_000

    func createPendingItemStatusesTable() throws {
        try database.run(pendingItemStatuses.create(ifNotExists: true) { table in
            table.column(pendingStatusURL, primaryKey: true)
            table.column(pendingStatusIsRead)
            table.column(pendingStatusIsBookmarked)
            table.column(pendingStatusModifiedAt)
            table.column(pendingStatusSyncID)
            table.column(pendingStatusReceivedAt)
        })
        _ = try? database.run(pendingItemStatuses.createIndex(pendingStatusSyncID, ifNotExists: true))
        _ = try? database.run(pendingItemStatuses.createIndex(pendingStatusReceivedAt, ifNotExists: true))
    }

    func parkRemoteItemStatus(
        url: String, isRead: Bool, isBookmarked: Bool, modifiedAt: Double, syncID: String
    ) throws {
        let existing = pendingItemStatuses.filter(pendingStatusURL == url)
        if let row = try database.pluck(existing), row[pendingStatusModifiedAt] > modifiedAt {
            return
        }
        try database.run(pendingItemStatuses.insert(
            or: .replace,
            pendingStatusURL <- url,
            pendingStatusIsRead <- isRead,
            pendingStatusIsBookmarked <- isBookmarked,
            pendingStatusModifiedAt <- modifiedAt,
            pendingStatusSyncID <- syncID,
            pendingStatusReceivedAt <- Date().timeIntervalSince1970
        ))
    }

    func hasPendingItemStatuses() -> Bool {
        ((try? database.scalar(pendingItemStatuses.count)) ?? 0) > 0
    }

    /// Call right after inserting a new item row. Doesn't mark the row dirty,
    /// so the status isn't echoed back to CloudKit.
    func applyPendingItemStatus(toInsertedArticleWithURL url: String) throws {
        let pending = pendingItemStatuses.filter(pendingStatusURL == url)
        guard let row = try database.pluck(pending) else { return }
        try database.run(articles.filter(articleURL == url).update(
            articleIsRead <- row[pendingStatusIsRead],
            articleIsBookmarked <- row[pendingStatusIsBookmarked],
            articleStatusModifiedAt <- row[pendingStatusModifiedAt],
            articleStatusSyncID <- row[pendingStatusSyncID]
        ))
        try database.run(pending.delete())
    }

    func removePendingItemStatus(syncID: String) {
        _ = try? database.run(pendingItemStatuses.filter(pendingStatusSyncID == syncID).delete())
    }

    func removeAllPendingItemStatuses() {
        _ = try? database.run(pendingItemStatuses.delete())
    }

    /// Drops statuses for items that never arrived, e.g. from feeds only
    /// followed on the other device.
    func prunePendingItemStatuses() {
        let cutoff = Date().timeIntervalSince1970 - Self.pendingItemStatusMaxAge
        _ = try? database.run(pendingItemStatuses.filter(pendingStatusReceivedAt < cutoff).delete())
        let count = (try? database.scalar(pendingItemStatuses.count)) ?? 0
        let overflow = count - Self.pendingItemStatusMaxCount
        guard overflow > 0 else { return }
        _ = try? database.run("""
            DELETE FROM pending_item_statuses WHERE url IN (
                SELECT url FROM pending_item_statuses ORDER BY received_at ASC LIMIT ?
            )
            """, overflow)
    }
}
