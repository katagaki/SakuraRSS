import Foundation

let ephemeralArticleID: Int64 = 0

extension Article {
    /// Articles created from the Open Article extension carry `id == 0`.
    var isEphemeral: Bool {
        id == ephemeralArticleID
    }

    /// Builds an ephemeral article for a given URL.
    static func ephemeral(url: String, title: String) -> Article {
        Article(
            id: ephemeralArticleID,
            feedID: ephemeralArticleID,
            title: title,
            url: url,
            author: nil,
            summary: nil,
            content: nil,
            imageURL: nil,
            carouselImageURLs: [],
            publishedDate: nil,
            isRead: true,
            isBookmarked: false,
            audioURL: nil,
            duration: nil
        )
    }
}
