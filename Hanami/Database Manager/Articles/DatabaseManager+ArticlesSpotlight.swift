import Foundation
@preconcurrency import SQLite

public nonisolated extension DatabaseManager {

    /// Projection carrying only the columns Spotlight indexes, so the AI summary
    /// and translation blobs stay out of a full-library reindex.
    func articlesForSpotlight(forFeedID fid: Int64) throws -> [Article] {
        let query = articles
            .select(
                articleID,
                articleFeedID,
                articleTitle,
                articleURL,
                articleAuthor,
                articleSummary,
                articleContent,
                articleImageURL,
                articlePublishedDate
            )
            .filter(articleFeedID == fid)
            .order(articlePublishedDate.desc)
        return try database.prepare(query).map { row in
            Article(
                id: row[articleID],
                feedID: row[articleFeedID],
                title: row[articleTitle],
                url: row[articleURL],
                author: row[articleAuthor],
                summary: row[articleSummary],
                content: row[articleContent],
                imageURL: row[articleImageURL],
                carouselImageURLs: [],
                publishedDate: row[articlePublishedDate].map { Date(timeIntervalSince1970: $0) },
                isRead: false,
                isBookmarked: false,
                audioURL: nil,
                duration: nil
            )
        }
    }
}
