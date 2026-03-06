import Foundation
import UIKit

extension FeedManager {

    // MARK: - X Profile Feeds

    @MainActor
    func refreshXFeed(_ feed: Feed) async throws {
        guard let handle = XProfileScraper.handleFromFeedURL(feed.url),
              let profileURL = XProfileScraper.profileURL(for: handle) else { return }

        let scraper = XProfileScraper()
        let result = await scraper.scrapeProfile(profileURL: profileURL)

        for tweet in result.tweets {
            let title = tweet.text.isEmpty
                ? "Post by @\(tweet.authorHandle)"
                : String(tweet.text.prefix(200))

            try database.insertArticle(
                feedID: feed.id,
                title: title,
                url: tweet.url,
                data: ArticleInsertData(
                    author: tweet.author.isEmpty ? "@\(tweet.authorHandle)" : tweet.author,
                    summary: tweet.text.isEmpty ? nil : tweet.text,
                    imageURL: tweet.imageURL,
                    publishedDate: tweet.publishedDate
                )
            )
        }

        // Update feed title with display name if available
        let feedTitle = result.displayName ?? feed.title

        // Download and cache the profile photo locally
        if let imageURLString = result.profileImageURL,
           let imageURL = URL(string: imageURLString),
           let (imageData, _) = try? await URLSession.shared.data(from: imageURL),
           let image = UIImage(data: imageData) {
            await FaviconCache.shared.setCustomFavicon(image, feedID: feed.id)
            if feed.customIconURL != "photo" || feed.title != feedTitle {
                try? database.updateFeedDetails(
                    id: feed.id, title: feedTitle, url: feed.url,
                    customIconURL: "photo"
                )
            }
        } else if feed.title != feedTitle {
            try? database.updateFeedDetails(
                id: feed.id, title: feedTitle, url: feed.url,
                customIconURL: feed.customIconURL
            )
        }

        try database.updateFeedLastFetched(id: feed.id, date: Date())
        loadFromDatabase()
    }

    /// Whether the user has any X profile feeds.
    var hasXFeeds: Bool {
        feeds.contains { XProfileScraper.isXFeedURL($0.url) }
    }
}
