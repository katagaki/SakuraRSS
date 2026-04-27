import Foundation
@preconcurrency import SQLite

nonisolated extension DatabaseManager {

    func deleteArticles(olderThan date: Date) throws {
        let target = articles.filter(
            (articlePublishedDate < date.timeIntervalSince1970 || articlePublishedDate == nil)
                && articleIsBookmarked == false
        )
        try database.run(target.delete())
    }

    func deleteAllArticlesOnly() throws {
        try database.run(articles.filter(articleIsBookmarked == false).delete())
    }

    func vacuum() throws {
        try database.run("VACUUM")
    }
}
