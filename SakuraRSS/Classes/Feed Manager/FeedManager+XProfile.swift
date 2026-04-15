import Foundation
import UIKit

extension FeedManager {

    // MARK: - X Profile Feeds

    /// Minimum interval between X API calls per feed (30 minutes).
    static let xRefreshInterval: TimeInterval = 30 * 60

    func refreshXFeed(_ feed: Feed, reloadData: Bool = true) async throws {
        if let lastFetched = feed.lastFetched,
           Date().timeIntervalSince(lastFetched) < Self.xRefreshInterval {
            #if DEBUG
            let remaining = Self.xRefreshInterval - Date().timeIntervalSince(lastFetched)
            print("[XProfile] Skipping refresh for @\(feed.title) — "
                  + "\(Int(remaining))s until next allowed fetch")
            #endif
            return
        }

        guard let handle = XProfileScraper.handleFromFeedURL(feed.url),
              let profileURL = XProfileScraper.profileURL(for: handle) else { return }

        let scraper = XProfileScraper()
        let result = await scraper.scrapeProfile(profileURL: profileURL)

        let tweetTuples = result.tweets.map { tweet in
            let title = tweet.text.isEmpty
                ? "Post by @\(tweet.authorHandle)"
                : String(tweet.text.prefix(200))
            return ArticleInsertItem(
                title: title,
                url: tweet.url,
                data: ArticleInsertData(
                    author: tweet.author.isEmpty ? "@\(tweet.authorHandle)" : tweet.author,
                    summary: tweet.text.isEmpty ? nil : tweet.text,
                    imageURL: tweet.imageURL,
                    carouselImageURLs: tweet.carouselImageURLs,
                    publishedDate: tweet.publishedDate
                )
            )
        }

        let feedTitle = result.displayName ?? feed.title

        var profileImage: UIImage?
        if feed.lastFetched == nil,
           let imageURLString = result.profileImageURL,
           let imageURL = URL(string: imageURLString),
           let (imageData, _) = try? await FaviconCache.urlSession.data(from: imageURL) {
            profileImage = UIImage(data: imageData)
        }

        let database = database
        try await Task.detached {
            try database.insertArticles(feedID: feed.id, articles: tweetTuples)
            try database.updateFeedLastFetched(id: feed.id, date: Date())
            let articlesToIndex = try database.articles(forFeedID: feed.id, limit: tweetTuples.count)
            SpotlightIndexer.indexArticles(articlesToIndex, feedTitle: feedTitle)
        }.value

        await applyScraperMetadataRefresh(
            feed: feed, scrapedTitle: feedTitle, profileImage: profileImage
        )

        if reloadData {
            await loadFromDatabaseInBackground()
        }
    }

    var hasXFeeds: Bool {
        feeds.contains { XProfileScraper.isXFeedURL($0.url) }
    }
}
