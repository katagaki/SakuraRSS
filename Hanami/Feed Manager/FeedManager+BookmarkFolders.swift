import Foundation

public extension FeedManager {

    static let defaultBookmarkFoldersCreatedKey = "Bookmarks.DefaultFoldersCreated"

    // MARK: - Folder CRUD

    @discardableResult
    func createBookmarkFolder(name: String, icon: String) throws -> Int64 {
        let sortOrder = bookmarkFolders.count
        let newID = try database.insertBookmarkFolder(name: name, icon: icon, sortOrder: sortOrder)
        loadFromDatabase()
        return newID
    }

    func updateBookmarkFolder(_ folder: BookmarkFolder, name: String, icon: String) {
        try? database.updateBookmarkFolder(id: folder.id, name: name, icon: icon)
        loadFromDatabase()
    }

    func updateBookmarkFolderDisplayStyle(_ folder: BookmarkFolder, displayStyle: String?) {
        try? database.updateBookmarkFolderDisplayStyle(id: folder.id, displayStyle: displayStyle)
        if let index = bookmarkFolders.firstIndex(where: { $0.id == folder.id }) {
            bookmarkFolders[index].displayStyle = displayStyle
        }
    }

    func deleteBookmarkFolder(_ folder: BookmarkFolder, removeBookmarks: Bool) {
        try? database.deleteBookmarkFolder(id: folder.id, removeBookmarks: removeBookmarks)
        loadFromDatabase()
    }

    // MARK: - Folder Membership

    /// Replaces the folder's contents with `articleIDs`. Articles selected here
    /// leave any other folder, keeping the one-folder-per-bookmark behavior.
    func setBookmarkFolderMembership(_ folder: BookmarkFolder, articleIDs: Set<Int64>) {
        let current = Set((try? database.articleIDs(inFolderID: folder.id)) ?? [])
        for removedID in current.subtracting(articleIDs) {
            try? database.removeBookmarkFromAllFolders(articleID: removedID)
        }
        for addedID in articleIDs.subtracting(current) {
            try? database.setBookmarkFolder(articleID: addedID, folderID: folder.id)
        }
        bumpDataRevision()
    }

    func bookmarkFolderArticleIDs(_ folder: BookmarkFolder) -> Set<Int64> {
        Set((try? database.articleIDs(inFolderID: folder.id)) ?? [])
    }

    func bookmarkFolderID(forArticleID articleID: Int64) -> Int64? {
        (try? database.bookmarkFolderID(forArticleID: articleID)) ?? nil
    }

    func moveBookmark(articleID: Int64, to folder: BookmarkFolder) {
        try? database.setBookmarkFolder(articleID: articleID, folderID: folder.id)
        bumpDataRevision()
    }

    // MARK: - Folder Article Queries

    func bookmarkedArticles(in folder: BookmarkFolder) -> [Article] {
        (try? database.bookmarkedArticles(inFolderID: folder.id)) ?? []
    }

    func unorganizedBookmarkedArticles() -> [Article] {
        (try? database.unorganizedBookmarkedArticles()) ?? []
    }

    func bookmarkCount(in folder: BookmarkFolder) -> Int {
        (try? database.bookmarkCount(inFolderID: folder.id)) ?? 0
    }

    func latestBookmarkThumbnailURLs(in folder: BookmarkFolder) -> [String] {
        (try? database.latestBookmarkThumbnailURLs(inFolderID: folder.id)) ?? []
    }

    // MARK: - Default Folders

    func createDefaultBookmarkFoldersIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.defaultBookmarkFoldersCreatedKey) else { return }
        defaults.set(true, forKey: Self.defaultBookmarkFoldersCreatedKey)
        let defaultFolders: [(name: String, icon: String)] = [
            (String(localized: "Folders.Default.ReadLater", table: "Articles"), "book.closed"),
            (String(localized: "Folders.Default.WatchLater", table: "Articles"), "play.rectangle"),
            (String(localized: "Folders.Default.ListenLater", table: "Articles"), "headphones")
        ]
        for (offset, folder) in defaultFolders.enumerated() {
            _ = try? database.insertBookmarkFolder(
                name: folder.name,
                icon: folder.icon,
                sortOrder: offset
            )
        }
    }
}
