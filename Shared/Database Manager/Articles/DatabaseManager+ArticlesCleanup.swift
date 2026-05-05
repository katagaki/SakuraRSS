import Foundation
@preconcurrency import SQLite

nonisolated extension DatabaseManager {

    func deleteArticles(olderThan date: Date, includeBookmarks: Bool = false) throws {
        let dateClause = articlePublishedDate < date.timeIntervalSince1970
            || articlePublishedDate == nil
        if includeBookmarks {
            try database.run(articles.filter(dateClause).delete())
        } else {
            try database.run(articles.filter(dateClause && articleIsBookmarked == false).delete())
        }
    }

    func deleteAllArticlesOnly(includeBookmarks: Bool = false) throws {
        if includeBookmarks {
            try database.run(articles.delete())
        } else {
            try database.run(articles.filter(articleIsBookmarked == false).delete())
        }
    }

    func vacuum() throws {
        try database.run("VACUUM")
    }
}
