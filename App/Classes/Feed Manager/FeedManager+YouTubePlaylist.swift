import Foundation
import UIKit

extension FeedManager {

    // MARK: - YouTube Playlist Feeds

    /// Minimum interval between YouTube playlist fetches per feed (30 minutes).
    private static let youTubePlaylistRefreshInterval: TimeInterval = 30 * 60

    // swiftlint:disable:next function_body_length
    func refreshYouTubePlaylistFeed(
        _ feed: Feed,
        reloadData: Bool = true,
        skipImagePreload: Bool = false,
        runNLP: Bool = true
    ) async throws {
        log("YouTubePlaylist", "refresh begin id=\(feed.id) title=\(feed.title)")
        if let lastFetched = feed.lastFetched,
           Date().timeIntervalSince(lastFetched) < Self.youTubePlaylistRefreshInterval {
            let remaining = Self.youTubePlaylistRefreshInterval
                - Date().timeIntervalSince(lastFetched)
            log("YouTubePlaylist", "Skipping refresh for \(feed.title) - \(Int(remaining))s until next allowed fetch")
            return
        }

        guard let playlistID = YouTubePlaylistFetcher.identifierFromFeedURL(feed.url) else {
            log("YouTubePlaylist", "Could not derive playlistID id=\(feed.id) url=\(feed.url)")
            return
        }
        log("YouTubePlaylist", "fetching playlistID=\(playlistID) id=\(feed.id)")

        let fetcher = YouTubePlaylistFetcher()
        let result = await fetcher.fetchPlaylist(playlistID: playlistID)
        // swiftlint:disable:next line_length
        log("YouTubePlaylist", "fetched playlistID=\(playlistID) videos=\(result.videos.count) playlistTitle=\(result.playlistTitle ?? "nil")")

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
           let (imageData, _) = try? await IconCache.urlSession.data(from: avatarURL) {
            avatarImage = UIImage(data: imageData)
        }

        let database = database
        let feedID = feed.id
        try await Task.detached {
            let insertedIDs = (try? database.insertArticles(
                feedID: feedID, articles: articleTuples
            )) ?? []
            log("YouTubePlaylist", "inserted id=\(feedID) new=\(insertedIDs.count)/\(articleTuples.count)")
            await FeedManager.runPostInsertPipeline(
                insertedIDs: insertedIDs,
                feedTitle: feedTitle,
                skipImagePreload: skipImagePreload,
                runNLP: runNLP
            )
            try database.updateFeedLastFetched(id: feedID, date: Date())
        }.value

        await applyFetcherMetadataRefresh(
            feed: feed, fetchdTitle: feedTitle, profileImage: avatarImage
        )

        await MainActor.run { self.bumpDataRevision() }
        if reloadData {
            await loadFromDatabaseInBackground(animated: true)
        }
        log("YouTubePlaylist", "refresh end id=\(feed.id)")
    }

    var hasYouTubePlaylistFeeds: Bool {
        feeds.contains { YouTubePlaylistFetcher.isFeedURL($0.url) }
    }
}
