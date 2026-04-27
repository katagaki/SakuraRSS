import Foundation
@preconcurrency import SQLite

nonisolated extension DatabaseManager {

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
}
