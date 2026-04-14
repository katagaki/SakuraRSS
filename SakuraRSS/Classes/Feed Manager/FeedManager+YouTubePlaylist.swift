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

        // Only install the downloaded channel avatar when the feed has
        // no custom icon yet. Once the user — or a prior refresh — has
        // assigned any custom icon, preserve it across refreshes so it
        // isn't silently overwritten. The avatar auto-installs on the
        // very first fetch; to pull a fresh avatar, the user can delete
        // the custom icon in the edit sheet.
        // If the user has customized the feed title, preserve their
        // override on refresh — `effectiveTitle` always carries the
        // stored title in that case so `updateFeedDetails` never
        // silently overwrites it with the scraped playlist title.
        let effectiveTitle = feed.isTitleCustomized ? feed.title : feedTitle
        let shouldInstallAvatar = avatarImage != nil && feed.customIconURL == nil
        if shouldInstallAvatar, let image = avatarImage {
            await FaviconCache.shared.setCustomFavicon(
                image, feedID: feed.id, skipTrimming: true
            )
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

    /// Whether the user has any YouTube playlist feeds.
    var hasYouTubePlaylistFeeds: Bool {
        feeds.contains { YouTubePlaylistScraper.isYouTubePlaylistFeedURL($0.url) }
    }
}
