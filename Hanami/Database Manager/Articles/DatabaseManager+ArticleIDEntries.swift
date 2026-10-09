import Foundation
@preconcurrency import SQLite

public nonisolated extension DatabaseManager {

    /// Dated IDs only, newest first, for preloads where no rule needs the text columns.
    func articleIDEntries(
        feedIDs: [Int64]? = nil,
        ids: [Int64]? = nil,
        excludingFeedIDs: Set<Int64> = [],
        requireUnread: Bool = false,
        limit: Int? = nil
    ) throws -> [ArticleIDEntry] {
        var query = feedArticles
            .select(articleID, articlePublishedDate)
            .filter(articlePublishedDate != nil)
        if let feedIDs {
            query = query.filter(feedIDs.contains(articleFeedID))
        }
        if let ids {
            query = query.filter(ids.contains(articleID))
        }
        if !excludingFeedIDs.isEmpty {
            query = query.filter(!excludingFeedIDs.contains(articleFeedID))
        }
        if requireUnread {
            query = query.filter(articleIsRead == false)
        }
        query = query.order(articlePublishedDate.desc)
        if let limit {
            query = query.limit(limit)
        }
        return try readDatabase.prepare(query).compactMap { row in
            guard let timestamp = row[articlePublishedDate] else { return nil }
            return ArticleIDEntry(id: row[articleID], publishedDate: Date(timeIntervalSince1970: timestamp))
        }
    }
}
