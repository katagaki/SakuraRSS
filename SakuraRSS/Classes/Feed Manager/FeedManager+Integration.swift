import Foundation
import UIKit

extension FeedManager {

    // MARK: - Generic Integration Refresh

    /// Refreshes a feed that is backed by an `Integration` subclass (X,
    /// Instagram, YouTube playlist, etc.). This unifies what used to be
    /// three near-identical `refreshXFeed` / `refreshInstagramFeed` /
    /// `refreshYouTubePlaylistFeed` methods into a single flow.
    ///
    /// The integration is responsible for:
    /// - Extracting its identifier from the pseudo-feed URL (via base class)
    /// - Scraping and transforming results into `ArticleInsertItem`s
    /// - Optionally providing a feed title and profile photo URL
    ///
    /// This method handles:
    /// - Rate limiting (using `Integration.refreshInterval`)
    /// - Database writes off the main thread
    /// - Profile photo download + favicon cache update
    /// - Feed title / custom icon updates
    /// - Spotlight indexing
    /// - UI reload
    func refreshIntegrationFeed(
        _ feed: Feed,
        integration: Integration,
        reloadData: Bool = true
    ) async throws {
        let integrationType = type(of: integration)

        // 1. Skip if this feed was fetched within the refresh interval
        if let lastFetched = feed.lastFetched,
           Date().timeIntervalSince(lastFetched) < integrationType.refreshInterval {
            #if DEBUG
            let remaining = integrationType.refreshInterval
                - Date().timeIntervalSince(lastFetched)
            print("[\(integrationType)] Skipping refresh for \(feed.title) — "
                  + "\(Int(remaining))s until next allowed fetch")
            #endif
            return
        }

        // 2. Extract identifier from the pseudo-feed URL
        guard let identifier = integrationType.identifierFromFeedURL(feed.url) else {
            return
        }

        // 3. Perform the platform-specific scrape
        let result = await integration.scrape(identifier: identifier)

        let articles = result.articles
        let feedTitle = result.feedTitle ?? feed.title

        // 4. Download profile photo if this integration supports it
        var profileImage: UIImage?
        if integrationType.supportsProfilePhoto,
           let imageURLString = result.profileImageURL,
           let imageURL = URL(string: imageURLString),
           let (imageData, _) = try? await URLSession.shared.data(from: imageURL) {
            profileImage = UIImage(data: imageData)
        }

        // 5. Run all DB writes off the main thread
        let database = database
        try await Task.detached {
            try database.insertArticles(feedID: feed.id, articles: articles)
            try database.updateFeedLastFetched(id: feed.id, date: Date())
            let articlesToIndex = try database.articles(
                forFeedID: feed.id, limit: articles.count
            )
            SpotlightIndexer.indexArticles(articlesToIndex, feedTitle: feedTitle)
        }.value

        // 6. Cache favicon and update feed details
        if let image = profileImage {
            await FaviconCache.shared.setCustomFavicon(
                image, feedID: feed.id, skipTrimming: true
            )
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

        // 7. Reload UI if requested
        if reloadData {
            await loadFromDatabaseInBackground()
        }
    }

    // MARK: - Integration Feed Presence

    /// Whether the user has any X profile feeds.
    var hasXFeeds: Bool {
        feeds.contains { XURLHelpers.isXFeedURL($0.url) }
    }

    /// Whether the user has any Instagram profile feeds.
    var hasInstagramFeeds: Bool {
        feeds.contains { InstagramURLHelpers.isInstagramFeedURL($0.url) }
    }

    /// Whether the user has any YouTube playlist feeds.
    var hasYouTubePlaylistFeeds: Bool {
        feeds.contains { YouTubePlaylistURLHelpers.isYouTubePlaylistFeedURL($0.url) }
    }
}
