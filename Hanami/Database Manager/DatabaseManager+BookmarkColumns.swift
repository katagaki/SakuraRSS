import Foundation
@preconcurrency import SQLite

nonisolated extension DatabaseManager {

    /// Adds the bookmark columns if they are missing.
    ///
    /// `fixup()` only runs when the app's version string changes, and SQLite
    /// resolves a double-quoted name that matches no column as a *string
    /// literal* rather than failing. A query selecting a column that doesn't
    /// exist yet therefore returns the column name for every row instead of an
    /// error, so these have to be guaranteed before any query can select them.
    func migrateBookmarkColumns() throws {
        let articleColumns = try columnNames(ofTable: "articles")
        if !articleColumns.contains("custom_title") {
            try database.run(articles.addColumn(articleCustomTitle))
        }
        if !articleColumns.contains("preview_fetch_state") {
            try database.run(articles.addColumn(articlePreviewFetchState, defaultValue: 0))
        }
        if !articleColumns.contains("preview_fetched_at") {
            try database.run(articles.addColumn(articlePreviewFetchedAt))
        }

        let folderColumns = try columnNames(ofTable: "bookmark_folders")
        if !folderColumns.contains("open_mode") {
            try database.run(bookmarkFolders.addColumn(bookmarkFolderOpenMode))
        }
        if !folderColumns.contains("marks_read_on_open") {
            try database.run(bookmarkFolders.addColumn(bookmarkFolderMarksReadOnOpen))
        }
    }

    func columnNames(ofTable table: String) throws -> Set<String> {
        var names: Set<String> = []
        for row in try database.prepare("PRAGMA table_info(\(table))") {
            if let name = row[1] as? String {
                names.insert(name)
            }
        }
        return names
    }
}
