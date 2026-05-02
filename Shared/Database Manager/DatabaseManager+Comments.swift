import Foundation
@preconcurrency import SQLite

nonisolated extension DatabaseManager {

    /// Returns cached comments for `articleID`, ordered by rank ascending.
    func cachedComments(forArticleID id: Int64) throws -> [Comment] {
        let query = comments
            .filter(commentArticleID == id)
            .order(commentRank.asc)
        return try database.prepare(query).map(rowToComment)
    }

    /// True if comments have ever been fetched for this article (even if zero).
    func hasFetchedComments(forArticleID id: Int64) throws -> Bool {
        let query = articles.filter(articleID == id).limit(1)
        guard let row = try database.pluck(query) else { return false }
        return row[articleCommentsFetchedAt] != nil
    }

    /// Replaces all stored comments for `articleID` with `items` and stamps
    /// the article's fetch time, so a follow-up open uses cache.
    func replaceComments(_ items: [FetchedComment], forArticleID id: Int64) throws {
        try database.transaction {
            let deleted = try database.run(comments.filter(commentArticleID == id).delete())
            for (rank, item) in items.enumerated() {
                try database.run(comments.insert(
                    commentArticleID <- id,
                    commentRank <- rank,
                    commentAuthor <- item.author,
                    commentBody <- item.body,
                    commentCreatedDate <- item.createdDate?.timeIntervalSince1970,
                    commentSourceURL <- item.sourceURL
                ))
            }
            let target = articles.filter(articleID == id)
            try database.run(target.update(
                articleCommentsFetchedAt <- Date().timeIntervalSince1970
            ))
            log("Comments", "DB replace article id=\(id) deleted=\(deleted) inserted=\(items.count)")
        }
    }

    /// Drops cached comments and the fetch marker, forcing a re-fetch.
    func clearCachedComments(forArticleID id: Int64) throws {
        try database.transaction {
            let deleted = try database.run(comments.filter(commentArticleID == id).delete())
            let target = articles.filter(articleID == id)
            try database.run(target.update(articleCommentsFetchedAt <- nil))
            log("Comments", "DB clear article id=\(id) deleted=\(deleted)")
        }
    }

    private func rowToComment(_ row: Row) -> Comment {
        Comment(
            id: row[commentID],
            articleID: row[commentArticleID],
            rank: row[commentRank],
            author: row[commentAuthor],
            body: row[commentBody],
            createdDate: row[commentCreatedDate].map { Date(timeIntervalSince1970: $0) },
            sourceURL: row[commentSourceURL]
        )
    }
}
