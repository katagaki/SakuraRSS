import Foundation
import UIKit

extension FeedManager {

    // MARK: - X Profile Feeds

    /// Minimum interval between X API calls per feed (30 minutes).
    /// Also used by `FaviconProgressBadge` to size the cooldown pie.
    static let xRefreshInterval: TimeInterval = 30 * 60

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

        // Download profile photo if available. This fetch is effectively
        // a favicon fetch and therefore uses the favicon cache's dedicated
        // URLSession, which bypasses the normal request timeout.
        var profileImage: UIImage?
        if let imageURLString = result.profileImageURL,
           let imageURL = URL(string: imageURLString),
           let (imageData, _) = try? await FaviconCache.urlSession.data(from: imageURL) {
            profileImage = UIImage(data: imageData)
        }

        // Run all DB writes off the main thread
        let database = database
        try await Task.detached {
            try database.insertArticles(feedID: feed.id, articles: tweetTuples)
            try database.updateFeedLastFetched(id: feed.id, date: Date())
            let articlesToIndex = try database.articles(forFeedID: feed.id, limit: tweetTuples.count)
            SpotlightIndexer.indexArticles(articlesToIndex, feedTitle: feedTitle)
        }.value

        // Cache favicon and update feed details.
        //
        // Only install the downloaded profile photo when the feed has
        // no custom icon yet (`customIconURL == nil`).  Once the user —
        // or a prior refresh — has assigned any custom icon, preserve
        // it across refreshes so it isn't silently overwritten.  This
        // means the X profile photo only auto-installs on the very
        // first fetch; to pull a fresh profile photo, the user can
        // delete the custom icon in the edit sheet.
        // If the user has customized the feed title, preserve their
        // override on refresh — `effectiveTitle` always carries the
        // stored title in that case so `updateFeedDetails` never
        // silently overwrites it with the scraped display name.
        let effectiveTitle = feed.isTitleCustomized ? feed.title : feedTitle
        let shouldInstallProfilePhoto = profileImage != nil && feed.customIconURL == nil
        if shouldInstallProfilePhoto, let image = profileImage {
            await FaviconCache.shared.setCustomFavicon(image, feedID: feed.id, skipTrimming: true)
            try? await Task.detached {
                try database.updateFeedDetails(
                    id: feed.id, title: effectiveTitle, url: feed.url,
                    customIconURL: "photo",
                    isTitleCustomized: feed.isTitleCustomized
                )
            }.value
        } else if feed.title != effectiveTitle {
            try? await Task.detached {
                try database.updateFeedDetails(
                    id: feed.id, title: effectiveTitle, url: feed.url,
                    customIconURL: feed.customIconURL,
                    isTitleCustomized: feed.isTitleCustomized
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
