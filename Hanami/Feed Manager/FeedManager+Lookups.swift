import Foundation

public extension FeedManager {

    // MARK: - Lookups

    var mutedFeedIDs: Set<Int64> {
        Set(feeds.filter(\.isMuted).map(\.id))
    }

    func feed(forArticle article: Article) -> Feed? {
        feedsByID[article.feedID]
    }

    /// Every feed stores its media images, but blogs list each inline image as
    /// media, so only social and Fediverse posts show theirs as a carousel.
    func carouselImageURLs(for article: Article) -> [String] {
        guard let feed = feed(forArticle: article),
              feed.isSocialFeed || feed.isFediverseFeed || feed.isBlueskyFeed else { return [] }
        return article.carouselImageURLs
    }

    /// Returns the raw article (no Content Override applied). The viewer relies on this
    /// to display the original RSS data; lists go through the override pipeline instead.
    ///
    /// Always reads from the database so the full `content` blob is present: the
    /// in-memory `articles` cache is a list projection that omits `content`.
    func article(byID id: Int64) -> Article? {
        (try? database.article(byID: id))
    }

}
