import Foundation
@preconcurrency import SQLite

public nonisolated extension DatabaseManager {

    /// `keeping` is content still open somewhere, which stays however old it is.
    func deleteArticles(olderThan date: Date, includeBookmarks: Bool = false, keeping: Set<Int64> = []) throws {
        let dateClause = articlePublishedDate < date.timeIntervalSince1970
            || articlePublishedDate == nil
        var query = articles.filter(dateClause)
        if !includeBookmarks {
            query = query.filter(articleIsBookmarked == false)
        }
        if !keeping.isEmpty {
            query = query.filter(!Array(keeping).contains(articleID))
        }
        try database.run(query.delete())
        try pruneOrphanedBookmarkFolderItems()
        try pruneOrphanedBookmarkTagItems()
    }

    func deleteAllArticlesOnly(includeBookmarks: Bool = false, keeping: Set<Int64> = []) throws {
        var query = articles
        if !includeBookmarks {
            query = query.filter(articleIsBookmarked == false)
        }
        if !keeping.isEmpty {
            query = query.filter(!Array(keeping).contains(articleID))
        }
        try database.run(query.delete())
        try clearAllHTTPValidators()
        try pruneOrphanedBookmarkFolderItems()
        try pruneOrphanedBookmarkTagItems()
    }

    func vacuum() throws {
        try database.run("VACUUM")
    }
}
