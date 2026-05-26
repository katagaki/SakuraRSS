import Foundation
@preconcurrency import SQLite

public nonisolated extension DatabaseManager {

    func rowToArticle(_ row: Row) -> Article {
        let carouselRaw = row[articleCarouselURLs]
        let carouselURLs = carouselRaw?
            .split(separator: "\n")
            .map(String.init) ?? []
        return Article(
            id: row[articleID],
            feedID: row[articleFeedID],
            title: row[articleTitle],
            url: row[articleURL],
            author: row[articleAuthor],
            summary: row[articleSummary],
            content: row[articleContent],
            imageURL: row[articleImageURL],
            carouselImageURLs: carouselURLs,
            publishedDate: row[articlePublishedDate].map { Date(timeIntervalSince1970: $0) },
            isRead: row[articleIsRead],
            isBookmarked: row[articleIsBookmarked],
            audioURL: row[articleAudioURL],
            duration: row[articleDuration]
        )
    }

    /// Restricts a query to the columns rendered in lists, omitting the heavy
    /// `content` blob so list loads never read full extracted HTML into memory.
    func selectingListColumns(_ query: Table) -> Table {
        query.select(
            articleID,
            articleFeedID,
            articleTitle,
            articleURL,
            articleAuthor,
            articleSummary,
            articleImageURL,
            articleCarouselURLs,
            articlePublishedDate,
            articleIsRead,
            articleIsBookmarked,
            articleAudioURL,
            articleDuration
        )
    }

    /// Maps a row selected via `selectingListColumns`. `content` is intentionally
    /// `nil`; the reader re-fetches the full row by id when an article is opened.
    func rowToListArticle(_ row: Row) -> Article {
        let carouselRaw = row[articleCarouselURLs]
        let carouselURLs = carouselRaw?
            .split(separator: "\n")
            .map(String.init) ?? []
        return Article(
            id: row[articleID],
            feedID: row[articleFeedID],
            title: row[articleTitle],
            url: row[articleURL],
            author: row[articleAuthor],
            summary: row[articleSummary],
            content: nil,
            imageURL: row[articleImageURL],
            carouselImageURLs: carouselURLs,
            publishedDate: row[articlePublishedDate].map { Date(timeIntervalSince1970: $0) },
            isRead: row[articleIsRead],
            isBookmarked: row[articleIsBookmarked],
            audioURL: row[articleAudioURL],
            duration: row[articleDuration]
        )
    }
}
