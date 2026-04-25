import Foundation
import UIKit

extension FeedManager {

    // MARK: - YouTube Playlist Feeds

    /// Minimum interval between YouTube playlist fetches per feed (30 minutes).
    private static let youTubePlaylistRefreshInterval: TimeInterval = 30 * 60

    func refreshYouTubePlaylistFeed(
        _ feed: Feed,
        reloadData: Bool = true,
        articleInsertCollector: ArticleInsertCollector? = nil
    ) async throws {
        if let lastFetched = feed.lastFetched,
           Date().timeIntervalSince(lastFetched) < Self.youTubePlaylistRefreshInterval {
            #if DEBUG
            let remaining = Self.youTubePlaylistRefreshInterval
                - Date().timeIntervalSince(lastFetched)
            print("[YouTubePlaylist] Skipping refresh for \(feed.title) - "
                  + "\(Int(remaining))s until next allowed fetch")
            #endif
            return
        }

        guard let playlistID = YouTubePlaylistScraper.playlistIDFromFeedURL(feed.url) else {
            return
        }

        let scraper = YouTubePlaylistScraper()
        let result = await scraper.scrapePlaylist(playlistID: playlistID)

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

        var avatarImage: UIImage?
        if feed.lastFetched == nil,
           let avatarURLString = result.channelAvatarURL,
           let avatarURL = URL(string: avatarURLString),
           let (imageData, _) = try? await FaviconCache.urlSession.data(from: avatarURL) {
            avatarImage = UIImage(data: imageData)
        }

        let database = database
        try await Task.detached {
            if let articleInsertCollector {
                await articleInsertCollector.add(
                    feedID: feed.id,
                    items: articleTuples,
                    feedTitleForSpotlight: feedTitle
                )
            } else {
                let insertedIDs = try database.insertArticles(
                    feedID: feed.id, articles: articleTuples
                )
                if !insertedIDs.isEmpty {
                    let articlesToIndex = try database.articles(withIDs: insertedIDs)
                    SpotlightIndexer.indexArticles(articlesToIndex, feedTitle: feedTitle)
                }
            }
            try database.updateFeedLastFetched(id: feed.id, date: Date())
        }.value

        await applyScraperMetadataRefresh(
            feed: feed, scrapedTitle: feedTitle, profileImage: avatarImage
        )

        if reloadData {
            await loadFromDatabaseInBackground(animated: true)
        }
    }

    var hasYouTubePlaylistFeeds: Bool {
        feeds.contains { YouTubePlaylistScraper.isYouTubePlaylistFeedURL($0.url) }
    }
}
