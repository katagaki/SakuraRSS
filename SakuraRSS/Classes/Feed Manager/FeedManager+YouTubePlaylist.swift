import Foundation
import UIKit

extension FeedManager {

    // MARK: - YouTube Playlist Feeds

    /// Minimum interval between YouTube playlist fetches per feed (30 minutes).
    private static let youTubePlaylistRefreshInterval: TimeInterval = 30 * 60

    func refreshYouTubePlaylistFeed(_ feed: Feed, reloadData: Bool = true) async throws {
        // Skip if this feed was fetched less than 30 minutes ago
        if let lastFetched = feed.lastFetched,
           Date().timeIntervalSince(lastFetched) < Self.youTubePlaylistRefreshInterval {
            #if DEBUG
            let remaining = Self.youTubePlaylistRefreshInterval
                - Date().timeIntervalSince(lastFetched)
            print("[YouTubePlaylist] Skipping refresh for \(feed.title) — "
                  + "\(Int(remaining))s until next allowed fetch")
            #endif
            return
        }

        guard let playlistID = YouTubePlaylistScraper.playlistIDFromFeedURL(feed.url) else {
            return
        }

        let scraper = YouTubePlaylistScraper()
        let result = await scraper.scrapePlaylist(playlistID: playlistID)

        // Convert playlist videos to article insert items
        let articleTuples = result.videos.map { video in
            ArticleInsertItem(
                title: video.title,
                url: "https://www.youtube.com/watch?v=\(video.videoId)",
                data: ArticleInsertData(
                    imageURL: video.thumbnailURL,
                    publishedDate: video.publishedDate
                )
            )
        }

        let feedTitle = result.playlistTitle ?? feed.title

        // Download the playlist creator's channel avatar if available.
        // Uses the favicon cache's dedicated URLSession so the request
        // bypasses the normal timeout — same as X / Instagram feeds.
        var avatarImage: UIImage?
        if let avatarURLString = result.channelAvatarURL,
           let avatarURL = URL(string: avatarURLString),
           let (imageData, _) = try? await FaviconCache.urlSession.data(from: avatarURL) {
            avatarImage = UIImage(data: imageData)
        }

        // Run all DB writes off the main thread
        let database = database
        try await Task.detached {
            try database.insertArticles(feedID: feed.id, articles: articleTuples)
            try database.updateFeedLastFetched(id: feed.id, date: Date())
            let articlesToIndex = try database.articles(
                forFeedID: feed.id, limit: articleTuples.count
            )
            SpotlightIndexer.indexArticles(articlesToIndex, feedTitle: feedTitle)
        }.value

        // Cache favicon and update feed details.  The shared helper
        // honours `isTitleCustomized` and only installs the downloaded
        // channel avatar when `customIconURL == nil`, so a user-assigned
        // icon or title survives every refresh.
        await applyScraperMetadataRefresh(
            feed: feed, scrapedTitle: feedTitle, profileImage: avatarImage
        )

        if reloadData {
            await loadFromDatabaseInBackground()
        }
    }

    /// Whether the user has any YouTube playlist feeds.
    var hasYouTubePlaylistFeeds: Bool {
        feeds.contains { YouTubePlaylistScraper.isYouTubePlaylistFeedURL($0.url) }
    }
}
