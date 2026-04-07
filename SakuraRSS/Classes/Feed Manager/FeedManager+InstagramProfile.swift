import Foundation
import UIKit

extension FeedManager {

    // MARK: - Instagram Profile Feeds

    /// Minimum interval between Instagram API calls per feed (30 minutes).
    private static let instagramRefreshInterval: TimeInterval = 30 * 60

    func refreshInstagramFeed(_ feed: Feed, reloadData: Bool = true) async throws {
        // Skip if this feed was fetched less than 30 minutes ago to avoid rate limits
        if let lastFetched = feed.lastFetched,
           Date().timeIntervalSince(lastFetched) < Self.instagramRefreshInterval {
            #if DEBUG
            let remaining = Self.instagramRefreshInterval - Date().timeIntervalSince(lastFetched)
            print("[InstagramProfile] Skipping refresh for @\(feed.title) — "
                  + "\(Int(remaining))s until next allowed fetch")
            #endif
            return
        }

        guard let handle = InstagramProfileScraper.handleFromFeedURL(feed.url),
              let profileURL = InstagramProfileScraper.profileURL(for: handle) else { return }

        let scraper = InstagramProfileScraper()
        let result = await scraper.scrapeProfile(profileURL: profileURL)

        // Prepare post data for batch insert
        let postTuples = result.posts.map { post in
            let title = post.text.isEmpty
                ? "Post by @\(post.authorHandle)"
                : String(post.text.prefix(200))
            return ArticleInsertItem(
                title: title,
                url: post.url,
                data: ArticleInsertData(
                    author: post.author.isEmpty ? "@\(post.authorHandle)" : post.author,
                    summary: post.text.isEmpty ? nil : post.text,
                    imageURL: post.imageURL,
                    publishedDate: post.publishedDate
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
            try database.insertArticles(feedID: feed.id, articles: postTuples)
            try database.updateFeedLastFetched(id: feed.id, date: Date())
        }.value

        // Cache favicon and update feed details
        if let image = profileImage {
            await FaviconCache.shared.setCustomFavicon(image, feedID: feed.id, skipTrimming: true)
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

    /// Whether the user has any Instagram profile feeds.
    var hasInstagramFeeds: Bool {
        feeds.contains { InstagramProfileScraper.isInstagramFeedURL($0.url) }
    }
}
