import Foundation

extension FeedManager {

    // MARK: - Lookups

    var mutedFeedIDs: Set<Int64> {
        Set(feeds.filter(\.isMuted).map(\.id))
    }

    func feed(forArticle article: Article) -> Feed? {
        feedsByID[article.feedID]
    }

    /// Returns the raw article (no Content Override applied). The viewer relies on this
    /// to display the original RSS data; lists go through the override pipeline instead.
    func article(byID id: Int64) -> Article? {
        articles.first { $0.id == id } ?? (try? database.article(byID: id))
    }

}
