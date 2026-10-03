import Foundation
@preconcurrency import SQLite

public nonisolated extension DatabaseManager {

    /// Every bookmark with the folder and tags it carries, ready for export.
    func exportableBookmarks() throws -> [ExportedBookmark] {
        let folderNamesByID = Dictionary(
            uniqueKeysWithValues: try allBookmarkFolders().map { ($0.id, $0.name) }
        )
        var folderNameByArticleID: [Int64: String] = [:]
        for row in try database.prepare(bookmarkFolderItems) {
            guard let name = folderNamesByID[row[bookmarkFolderItemFolderID]] else { continue }
            folderNameByArticleID[row[bookmarkFolderItemArticleID]] = name
        }

        let tagNamesByID = Dictionary(
            uniqueKeysWithValues: try allBookmarkTags().map { ($0.id, $0.name) }
        )
        var tagNamesByArticleID: [Int64: [String]] = [:]
        for row in try database.prepare(bookmarkTagItems) {
            guard let name = tagNamesByID[row[bookmarkTagItemTagID]] else { continue }
            tagNamesByArticleID[row[bookmarkTagItemArticleID], default: []].append(name)
        }

        let query = articles
            .filter(articleIsBookmarked == true)
            .order(articlePublishedDate.desc)
        return try database.prepare(query).map { row in
            let identifier = row[articleID]
            return ExportedBookmark(
                title: rowToArticle(row).displayTitle,
                originalTitle: row[articleTitle],
                url: row[articleURL],
                folder: folderNameByArticleID[identifier],
                tags: tagNamesByArticleID[identifier]?.sorted() ?? [],
                savedDate: row[articlePublishedDate].map { Date(timeIntervalSince1970: $0) },
                isRead: row[articleIsRead]
            )
        }
    }
}
