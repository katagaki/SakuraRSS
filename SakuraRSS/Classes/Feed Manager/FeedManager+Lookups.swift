import Foundation

extension FeedManager {

    // MARK: - Lookups

    var mutedFeedIDs: Set<Int64> {
        Set(feeds.filter(\.isMuted).map(\.id))
    }

    func feed(forArticle article: Article) -> Feed? {
        feedsByID[article.feedID]
    }

    func article(byID id: Int64) -> Article? {
        articles.first { $0.id == id } ?? (try? database.article(byID: id))
    }

}
