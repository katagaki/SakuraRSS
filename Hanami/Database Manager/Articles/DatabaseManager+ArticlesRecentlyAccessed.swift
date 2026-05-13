import Foundation
@preconcurrency import SQLite

public nonisolated extension DatabaseManager {

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

    /// Per-feed count of articles the user has explicitly opened since the
    /// given date. Drives implicit feed engagement ranking.
    func feedAccessCounts(since date: Date) throws -> [Int64: Int] {
        let sql = """
            SELECT feed_id, COUNT(*) AS cnt
            FROM articles
            WHERE last_accessed IS NOT NULL
              AND last_accessed >= ?
            GROUP BY feed_id
            """
        log("SQLite", "feedAccessCounts(since:) - \(sql)")
        var result: [Int64: Int] = [:]
        for row in try database.prepare(sql, date.timeIntervalSince1970) {
            guard let feedId = row[0] as? Int64,
                  let count = row[1] as? Int64 else { continue }
            result[feedId] = Int(count)
        }
        return result
    }

    /// Top entities by frequency, restricted to articles the user has
    /// explicitly opened since the given date. Pass `nil` for `types` to
    /// include every entity type.
    func topAccessedEntities(
        types: [String]?,
        since date: Date,
        limit: Int
    ) throws -> [(name: String, count: Int)] {
        var bindings: [Binding?] = [date.timeIntervalSince1970 as Binding?]
        var typeClause = ""
        if let types, !types.isEmpty {
            let placeholders = types.map { _ in "?" }.joined(separator: ", ")
            typeClause = "AND ne.type IN (\(placeholders))"
            bindings.append(contentsOf: types.map { $0 as Binding? })
        }
        bindings.append(limit as Binding?)
        let sql = """
            SELECT ne.name, COUNT(*) AS cnt
            FROM nlp_entities ne
            JOIN articles a ON ne.article_id = a.id
            WHERE a.last_accessed IS NOT NULL
              AND a.last_accessed >= ?
              \(typeClause)
            GROUP BY LOWER(ne.name)
            ORDER BY cnt DESC
            LIMIT ?
            """
        log("SQLite", "topAccessedEntities(types:since:limit:) - \(sql)")
        var results: [(name: String, count: Int)] = []
        for row in try database.prepare(sql, bindings) {
            if let name = row[0] as? String, let count = row[1] as? Int64 {
                results.append((name: name, count: Int(count)))
            }
        }
        return results
    }
}
