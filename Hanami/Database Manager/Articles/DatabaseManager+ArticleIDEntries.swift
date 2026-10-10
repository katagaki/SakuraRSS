import Foundation
@preconcurrency import SQLite

public nonisolated extension DatabaseManager {

    /// Dated IDs only, newest first, for preloads where no rule needs the text columns.
    /// `includingExternal` also covers pages saved from outside the app.
    func articleIDEntries(
        feedIDs: [Int64]? = nil,
        ids: [Int64]? = nil,
        excludingFeedIDs: Set<Int64> = [],
        requireUnread: Bool = false,
        includingExternal: Bool = false,
        limit: Int? = nil
    ) throws -> [ArticleIDEntry] {
        var query = (includingExternal ? articles : feedArticles)
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

    /// Mutes and read state are applied before the limit, as in `articleIDEntries`.
    func allArticlesList(excludingFeedIDs: Set<Int64>, requireUnread: Bool, limit: Int) throws -> [Article] {
        var query = selectingListColumns(feedArticles)
        if !excludingFeedIDs.isEmpty {
            query = query.filter(!excludingFeedIDs.contains(articleFeedID))
        }
        if requireUnread {
            query = query.filter(articleIsRead == false)
        }
        return try readDatabase
            .prepare(query.order(articlePublishedDate.desc).limit(limit))
            .map(rowToListArticle)
    }
}
