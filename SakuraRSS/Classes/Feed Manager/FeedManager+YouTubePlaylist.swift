import Foundation
import UIKit

extension FeedManager {

    // MARK: - YouTube Playlist Feeds

    /// Minimum interval between YouTube playlist fetches per feed (30 minutes).
    private static let youTubePlaylistRefreshInterval: TimeInterval = 30 * 60

    func refreshYouTubePlaylistFeed(
        _ feed: Feed,
        reloadData: Bool = true,
        skipImagePreload: Bool = false,
        runNLP: Bool = true
    ) async throws {
        #if DEBUG
        print("[YouTubePlaylist] refresh begin id=\(feed.id) title=\(feed.title)")
        #endif
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

        guard let playlistID = YouTubePlaylistFetcher.identifierFromFeedURL(feed.url) else {
            #if DEBUG
            print("[YouTubePlaylist] Could not derive playlistID id=\(feed.id) "
                  + "url=\(feed.url)")
            #endif
            return
        }
        #if DEBUG
        print("[YouTubePlaylist] fetching playlistID=\(playlistID) id=\(feed.id)")
        #endif

        let fetcher = YouTubePlaylistFetcher()
        let result = await fetcher.fetchPlaylist(playlistID: playlistID)
        #if DEBUG
        print("[YouTubePlaylist] fetched playlistID=\(playlistID) "
              + "videos=\(result.videos.count) "
              + "playlistTitle=\(result.playlistTitle ?? "nil")")
        #endif

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
        let feedID = feed.id
        try await Task.detached {
            let insertedIDs = (try? database.insertArticles(
                feedID: feedID, articles: articleTuples
            )) ?? []
            #if DEBUG
            print("[YouTubePlaylist] inserted id=\(feedID) "
                  + "new=\(insertedIDs.count)/\(articleTuples.count)")
            #endif
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
        #if DEBUG
        print("[YouTubePlaylist] refresh end id=\(feed.id)")
        #endif
    }

    var hasYouTubePlaylistFeeds: Bool {
        feeds.contains { YouTubePlaylistFetcher.isFeedURL($0.url) }
    }
}
