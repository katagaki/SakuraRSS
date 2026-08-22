import Foundation
@preconcurrency import SQLite

public nonisolated struct ItemStatusChange: Sendable {
    public let url: String
    public let isRead: Bool
    public let isBookmarked: Bool
    public let modifiedAt: Double
}

public nonisolated extension DatabaseManager {

    // MARK: - Reading Dirty Rows

    func dirtyItemStatuses(limit: Int? = nil) throws -> [ItemStatusChange] {
        var query = articles
            .filter(articleStatusDirty == true)
            .select(articleURL, articleIsRead, articleIsBookmarked, articleStatusModifiedAt)
        if let limit {
            query = query.limit(limit)
        }
        return try database.prepare(query).map { row in
            ItemStatusChange(
                url: row[articleURL],
                isRead: row[articleIsRead],
                isBookmarked: row[articleIsBookmarked],
                modifiedAt: (try? row.get(articleStatusModifiedAt)) ?? 0
            )
        }
    }

    func itemStatus(byStatusSyncID syncID: String) throws -> ItemStatusChange? {
        guard let row = try database.pluck(articles.filter(articleStatusSyncID == syncID)) else { return nil }
        return ItemStatusChange(
            url: row[articleURL],
            isRead: row[articleIsRead],
            isBookmarked: row[articleIsBookmarked],
            modifiedAt: (try? row.get(articleStatusModifiedAt)) ?? 0
        )
    }

    // MARK: - Upload Bookkeeping

    func setItemStatusSyncIDs(_ pairs: [(url: String, syncID: String)]) {
        guard !pairs.isEmpty else { return }
        _ = try? database.transaction {
            for pair in pairs {
                _ = try database.run(
                    articles.filter(articleURL == pair.url).update(articleStatusSyncID <- pair.syncID)
                )
            }
        }
    }

    func clearItemStatusDirty(urls: [String]) {
        guard !urls.isEmpty else { return }
        _ = try? database.run(articles.filter(urls.contains(articleURL)).update(articleStatusDirty <- false))
    }

    // MARK: - Applying Remote Status

    /// Applies a status record fetched from CloudKit. Last-writer-wins on the
    /// user-modified timestamp; never marks the row dirty so applying a remote
    /// change is not echoed back.
    @discardableResult
    func applyRemoteItemStatus(
        url: String, isRead: Bool, isBookmarked: Bool, modifiedAt: Double, syncID: String
    ) throws -> Bool {
        guard let row = try database.pluck(articles.filter(articleURL == url)) else { return false }
        let localModified = (try? row.get(articleStatusModifiedAt)) ?? 0
        guard modifiedAt >= localModified else {
            _ = try? database.run(articles.filter(articleURL == url).update(articleStatusSyncID <- syncID))
            return false
        }
        try database.run(articles.filter(articleURL == url).update(
            articleIsRead <- isRead,
            articleIsBookmarked <- isBookmarked,
            articleStatusModifiedAt <- modifiedAt,
            articleStatusSyncID <- syncID
        ))
        if !isBookmarked {
            try? removeBookmarkFromAllFolders(articleID: row[articleID])
        }
        return true
    }

    // MARK: - Migration

    /// Backfills dirty flags for every already-read or bookmarked item so a
    /// user upgrading into this version uploads their existing statuses once.
    func migrateItemStatusesForSync() throws {
        let now = Date().timeIntervalSince1970
        let target = articles.filter(articleIsRead == true || articleIsBookmarked == true)
        try database.run(target.update(
            articleStatusModifiedAt <- now,
            articleStatusDirty <- true
        ))
    }

    // MARK: - Cleanup

    /// Sync IDs of soon-to-be-deleted items that were uploaded, so the engine
    /// can delete their CloudKit records instead of leaving them orphaned.
    func uploadedStatusSyncIDs(olderThan date: Date, includeBookmarks: Bool) throws -> [String] {
        let dateClause = articlePublishedDate < date.timeIntervalSince1970 || articlePublishedDate == nil
        var query = articles.filter(dateClause && articleStatusSyncID != nil)
        if !includeBookmarks {
            query = query.filter(articleIsBookmarked == false)
        }
        return try database.prepare(query.select(articleStatusSyncID)).compactMap { try? $0.get(articleStatusSyncID) }
    }

    func allUploadedStatusSyncIDs(includeBookmarks: Bool) throws -> [String] {
        var query = articles.filter(articleStatusSyncID != nil)
        if !includeBookmarks {
            query = query.filter(articleIsBookmarked == false)
        }
        return try database.prepare(query.select(articleStatusSyncID)).compactMap { try? $0.get(articleStatusSyncID) }
    }
}
