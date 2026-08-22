import Foundation
@preconcurrency import SQLite

public nonisolated extension DatabaseManager {

    func articlesList(
        forFeedID fid: Int64,
        from startDate: Date,
        to endDate: Date,
        limit: Int = 200
    ) throws -> [Article] {
        let query = selectingListColumns(articles)
            .filter(articleFeedID == fid
                    && articlePublishedDate >= startDate.timeIntervalSince1970
                    && articlePublishedDate < endDate.timeIntervalSince1970)
            .order(articlePublishedDate.desc)
            .limit(limit)
        return try database.prepare(query).map(rowToListArticle)
    }

    func articlesList(
        forFeedIDs feedIDs: Set<Int64>,
        from startDate: Date,
        to endDate: Date,
        limit: Int = 200
    ) throws -> [Article] {
        guard !feedIDs.isEmpty else { return [] }
        let query = selectingListColumns(articles)
            .filter(feedIDs.contains(articleFeedID)
                    && articlePublishedDate >= startDate.timeIntervalSince1970
                    && articlePublishedDate < endDate.timeIntervalSince1970)
            .order(articlePublishedDate.desc)
            .limit(limit)
        return try database.prepare(query).map(rowToListArticle)
    }

}
