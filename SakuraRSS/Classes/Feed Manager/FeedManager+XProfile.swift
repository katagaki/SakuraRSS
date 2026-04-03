import Foundation
import UIKit

extension FeedManager {

    // MARK: - X Profile Feeds

    /// Minimum interval between X API calls per feed (30 minutes).
    private static let xRefreshInterval: TimeInterval = 30 * 60

    func refreshXFeed(_ feed: Feed, reloadData: Bool = true) async throws {
        // Skip if this feed was fetched less than 30 minutes ago to avoid rate limits
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

        // Prepare tweet data for batch insert
        let tweetTuples = result.tweets.map { tweet in
            let title = tweet.text.isEmpty
                ? "Post by @\(tweet.authorHandle)"
                : String(tweet.text.prefix(200))
            return (
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

        let feedTitle = result.displayName ?? feed.title

        // Download profile photo if available
        var profileImage: UIImage?
        if let imageURLString = result.profileImageURL,
           let imageURL = URL(string: imageURLString),
           let (imageData, _) = try? await URLSession.shared.data(from: imageURL) {
            profileImage = UIImage(data: imageData)
        }

        // Run all DB writes off the main thread
        let database = database
        try await Task.detached {
            try database.insertArticles(feedID: feed.id, articles: tweetTuples)
            try database.updateFeedLastFetched(id: feed.id, date: Date())
        }.value

        // Cache favicon and update feed details
        if let image = profileImage {
            await FaviconCache.shared.setCustomFavicon(image, feedID: feed.id)
            if feed.customIconURL != "photo" || feed.title != feedTitle {
                try? await Task.detached {
                    try database.updateFeedDetails(
                        id: feed.id, title: feedTitle, url: feed.url,
                        customIconURL: "photo"
                    )
                }.value
            }
        } else if feed.title != feedTitle {
            try? await Task.detached {
                try database.updateFeedDetails(
                    id: feed.id, title: feedTitle, url: feed.url,
                    customIconURL: feed.customIconURL
                )
            }.value
        }

        if reloadData {
            await loadFromDatabaseInBackground()
        }
    }

    /// Whether the user has any X profile feeds.
    var hasXFeeds: Bool {
        feeds.contains { XProfileScraper.isXFeedURL($0.url) }
    }
}
