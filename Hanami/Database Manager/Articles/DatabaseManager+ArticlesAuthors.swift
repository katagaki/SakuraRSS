import Foundation
@preconcurrency import SQLite

public nonisolated extension DatabaseManager {

    /// Distinct non-empty authors for a feed, ordered by each author's most
    /// recent article so the result matches a published-date-descending walk.
    func distinctAuthors(forFeedID fid: Int64) throws -> [String] {
        let sql = """
            SELECT author FROM articles
            WHERE feed_id = ? AND author IS NOT NULL AND author != ''
            GROUP BY author
            ORDER BY MAX(published_date) DESC
            """
        log("SQLite", "distinctAuthors(forFeedID:) - \(sql)")
        return try database.prepare(sql, [fid as Binding?]).compactMap { $0[0] as? String }
    }
}
