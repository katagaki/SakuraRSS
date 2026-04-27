import Foundation
@preconcurrency import SQLite

nonisolated extension DatabaseManager {

    func updateLastAccessed(articleID id: Int64) throws {
        let target = articles.filter(articleID == id)
        try database.run(target.update(articleLastAccessed <- Date().timeIntervalSince1970))
    }

    /// Batched counterpart of `updateLastAccessed(articleID:)`.
    func updateLastAccessed(articleIDs ids: [Int64]) throws {
        guard !ids.isEmpty else { return }
        let target = articles.filter(ids.contains(articleID))
        try database.run(target.update(articleLastAccessed <- Date().timeIntervalSince1970))
    }

    func recentlyAccessedArticles(limit: Int = 20) throws -> [Article] {
        let query = articles
            .filter(articleLastAccessed != nil)
            .order(articleLastAccessed.desc)
            .limit(limit)
        return try database.prepare(query).map(rowToArticle)
    }

    func clearAccessHistory() throws {
        try database.run(articles.update(articleLastAccessed <- nil))
    }
}
