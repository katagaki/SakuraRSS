import Foundation
@preconcurrency import SQLite

public nonisolated extension DatabaseManager {

    func unreadBookmarkedArticles(limit: Int = 2000) throws -> [Article] {
        let query = selectingListColumns(articles)
            .filter(articleIsBookmarked == true && articleIsRead == false)
            .order(articlePublishedDate.desc)
            .limit(limit)
        return try database.prepare(query).map(rowToListArticle)
    }

    func unreadBookmarkedCount() throws -> Int {
        try database.scalar(
            articles.filter(articleIsBookmarked == true && articleIsRead == false).count
        )
    }

    func unorganizedBookmarkedCount() throws -> Int {
        let organizedIDs = try database.prepare(
            bookmarkFolderItems.select(bookmarkFolderItemArticleID)
        ).map { $0[bookmarkFolderItemArticleID] }
        var query = articles.filter(articleIsBookmarked == true)
        if !organizedIDs.isEmpty {
            query = query.filter(!organizedIDs.contains(articleID))
        }
        return try database.scalar(query.count)
    }

    /// Tag names for every bookmark, so searching a list already in memory
    /// doesn't need a query per row.
    func bookmarkTagNamesByArticleID() throws -> [Int64: [String]] {
        let namesByTagID = Dictionary(
            uniqueKeysWithValues: try allBookmarkTags().map { ($0.id, $0.name) }
        )
        guard !namesByTagID.isEmpty else { return [:] }
        var result: [Int64: [String]] = [:]
        for row in try database.prepare(bookmarkTagItems) {
            guard let name = namesByTagID[row[bookmarkTagItemTagID]] else { continue }
            result[row[bookmarkTagItemArticleID], default: []].append(name)
        }
        return result
    }
}
