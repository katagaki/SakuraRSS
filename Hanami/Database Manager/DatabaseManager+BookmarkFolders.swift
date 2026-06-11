import Foundation
@preconcurrency import SQLite

public nonisolated extension DatabaseManager {

    // MARK: - Folder CRUD

    @discardableResult
    func insertBookmarkFolder(name: String, icon: String, displayStyle: String? = nil,
                              sortOrder: Int, parentFolderID: Int64? = nil) throws -> Int64 {
        try database.run(bookmarkFolders.insert(
            bookmarkFolderName <- name,
            bookmarkFolderIcon <- icon,
            bookmarkFolderDisplayStyle <- displayStyle,
            bookmarkFolderSortOrder <- sortOrder,
            bookmarkFolderParentID <- parentFolderID
        ))
    }

    func allBookmarkFolders() throws -> [BookmarkFolder] {
        try database.prepare(
            bookmarkFolders.order(bookmarkFolderSortOrder.asc, bookmarkFolderName.asc)
        ).map(rowToBookmarkFolder)
    }

    func bookmarkFolder(byID id: Int64) throws -> BookmarkFolder? {
        guard let row = try database.pluck(bookmarkFolders.filter(bookmarkFolderID == id)) else { return nil }
        return rowToBookmarkFolder(row)
    }

    func updateBookmarkFolder(id: Int64, name: String, icon: String) throws {
        let target = bookmarkFolders.filter(bookmarkFolderID == id)
        try database.run(target.update(
            bookmarkFolderName <- name,
            bookmarkFolderIcon <- icon
        ))
    }

    func updateBookmarkFolderDisplayStyle(id: Int64, displayStyle: String?) throws {
        let target = bookmarkFolders.filter(bookmarkFolderID == id)
        try database.run(target.update(bookmarkFolderDisplayStyle <- displayStyle))
    }

    /// Deletes a folder. When `removeBookmarks` is true the bookmarks inside are
    /// un-bookmarked; otherwise they return to the unorganized Bookmarks area.
    func deleteBookmarkFolder(id: Int64, removeBookmarks: Bool) throws {
        if removeBookmarks {
            let ids = try articleIDs(inFolderID: id)
            if !ids.isEmpty {
                let target = articles.filter(ids.contains(articleID))
                try database.run(target.update(articleIsBookmarked <- false))
            }
        }
        try database.run(bookmarkFolderItems.filter(bookmarkFolderItemFolderID == id).delete())
        try database.run(bookmarkFolders.filter(bookmarkFolderID == id).delete())
    }

    // MARK: - Folder Membership

    /// Places an article into a folder. The schema allows membership in multiple
    /// folders, but the app keeps one folder per bookmark, so existing links are
    /// cleared first.
    func setBookmarkFolder(articleID aid: Int64, folderID fid: Int64) throws {
        try removeBookmarkFromAllFolders(articleID: aid)
        try database.run(bookmarkFolderItems.insert(
            or: .ignore,
            bookmarkFolderItemFolderID <- fid,
            bookmarkFolderItemArticleID <- aid
        ))
    }

    func removeBookmarkFromAllFolders(articleID aid: Int64) throws {
        try database.run(bookmarkFolderItems.filter(bookmarkFolderItemArticleID == aid).delete())
    }

    func articleIDs(inFolderID fid: Int64) throws -> [Int64] {
        try database.prepare(
            bookmarkFolderItems
                .filter(bookmarkFolderItemFolderID == fid)
                .select(bookmarkFolderItemArticleID)
        ).map { $0[bookmarkFolderItemArticleID] }
    }

    func bookmarkFolderID(forArticleID aid: Int64) throws -> Int64? {
        try database.pluck(
            bookmarkFolderItems
                .filter(bookmarkFolderItemArticleID == aid)
                .select(bookmarkFolderItemFolderID)
        )?[bookmarkFolderItemFolderID]
    }

    // MARK: - Folder Article Queries

    func bookmarkedArticles(inFolderID fid: Int64) throws -> [Article] {
        let ids = try articleIDs(inFolderID: fid)
        guard !ids.isEmpty else { return [] }
        let query = articles
            .filter(ids.contains(articleID) && articleIsBookmarked == true)
            .order(articlePublishedDate.desc)
        return try database.prepare(query).map(rowToArticle)
    }

    func unorganizedBookmarkedArticles() throws -> [Article] {
        let organizedIDs = try database.prepare(
            bookmarkFolderItems.select(bookmarkFolderItemArticleID)
        ).map { $0[bookmarkFolderItemArticleID] }
        var query = articles.filter(articleIsBookmarked == true)
        if !organizedIDs.isEmpty {
            query = query.filter(!organizedIDs.contains(articleID))
        }
        return try database.prepare(query.order(articlePublishedDate.desc)).map(rowToArticle)
    }

    func bookmarkCount(inFolderID fid: Int64) throws -> Int {
        let ids = try articleIDs(inFolderID: fid)
        guard !ids.isEmpty else { return 0 }
        return try database.scalar(
            articles.filter(ids.contains(articleID) && articleIsBookmarked == true).count
        )
    }

    /// Image URLs of the latest bookmarks in a folder that have a thumbnail,
    /// used for the stacked-photos look of the folder grid cell.
    func latestBookmarkThumbnailURLs(inFolderID fid: Int64, limit: Int = 3) throws -> [String] {
        let ids = try articleIDs(inFolderID: fid)
        guard !ids.isEmpty else { return [] }
        let query = articles
            .filter(ids.contains(articleID) && articleIsBookmarked == true && articleImageURL != nil)
            .order(articlePublishedDate.desc)
            .limit(limit)
            .select(articleImageURL)
        return try database.prepare(query).compactMap { $0[articleImageURL] }
    }

    /// Drops folder links whose article was deleted or is no longer bookmarked.
    func pruneOrphanedBookmarkFolderItems() throws {
        try database.run("""
            DELETE FROM bookmark_folder_items WHERE article_id NOT IN \
            (SELECT id FROM articles WHERE is_bookmarked = 1)
            """)
    }

    // MARK: - Row Mapping

    func rowToBookmarkFolder(_ row: Row) -> BookmarkFolder {
        BookmarkFolder(
            id: row[bookmarkFolderID],
            name: row[bookmarkFolderName],
            icon: row[bookmarkFolderIcon],
            displayStyle: row[bookmarkFolderDisplayStyle],
            sortOrder: row[bookmarkFolderSortOrder],
            parentFolderID: row[bookmarkFolderParentID]
        )
    }
}
