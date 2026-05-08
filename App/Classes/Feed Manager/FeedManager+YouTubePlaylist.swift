import Foundation
import UIKit

extension FeedManager {

    // MARK: - YouTube Playlist Feeds

    private static let youTubePlaylistRefreshInterval: TimeInterval = 30 * 60

    func refreshYouTubePlaylistFeed(
        _ feed: Feed,
        reloadData: Bool = true,
        skipImagePreload: Bool = false,
        runNLP: Bool = true,
        contentOnly: Bool = false
    ) async throws {
        log("YouTubePlaylist", "refresh begin id=\(feed.id) title=\(feed.title) contentOnly=\(contentOnly)")
        if let lastFetched = feed.lastFetched,
           Date().timeIntervalSince(lastFetched) < Self.youTubePlaylistRefreshInterval {
            let remaining = Self.youTubePlaylistRefreshInterval
                - Date().timeIntervalSince(lastFetched)
            log("YouTubePlaylist", "Skipping refresh for \(feed.title) - \(Int(remaining))s until next allowed fetch")
            return
        }

        guard let playlistID = YouTubePlaylistProvider.identifierFromFeedURL(feed.url) else {
            log("YouTubePlaylist", "Could not derive playlistID id=\(feed.id) url=\(feed.url)")
            return
        }
        log("YouTubePlaylist", "fetching playlistID=\(playlistID) id=\(feed.id)")

        let fetcher = YouTubePlaylistProvider()
        let result = await fetcher.fetchPlaylist(playlistID: playlistID)
        // swiftlint:disable:next line_length
        log("YouTubePlaylist", "fetched playlistID=\(playlistID) videos=\(result.videos.count) playlistTitle=\(result.playlistTitle ?? "nil")")

        let articleTuples = Self.makeYouTubePlaylistArticleItems(from: result.videos)
        let feedTitle = result.playlistTitle ?? feed.title
        let avatarImage = await loadYouTubeChannelAvatar(
            result: result, feed: feed, contentOnly: contentOnly
        )

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

        if !contentOnly {
            await applyFetcherMetadataRefresh(
                feed: feed, fetchdTitle: feedTitle, profileImage: avatarImage
            )
        }

        if reloadData {
            await loadFromDatabaseInBackground(animated: true)
        }
        log("YouTubePlaylist", "refresh end id=\(feed.id)")
    }

    private static func makeYouTubePlaylistArticleItems(
        from videos: [ParsedPlaylistVideo]
    ) -> [ArticleInsertItem] {
        videos.map { video in
            ArticleInsertItem(
                title: video.title,
                url: "https://www.youtube.com/watch?v=\(video.videoId)",
                data: ArticleInsertData(
                    imageURL: video.thumbnailURL,
                    publishedDate: video.publishedDate
                )
            )
        }
    }

    private func loadYouTubeChannelAvatar(
        result: YouTubePlaylistFetchResult, feed: Feed, contentOnly: Bool
    ) async -> UIImage? {
        guard !contentOnly, feed.lastFetched == nil,
              let avatarURLString = result.channelAvatarURL,
              let avatarURL = URL(string: avatarURLString),
              let (imageData, _) = try? await IconCache.urlSession.data(from: avatarURL) else {
            return nil
        }
        return UIImage(data: imageData)
    }

    var hasYouTubePlaylistFeeds: Bool {
        feeds.contains { YouTubePlaylistProvider.isFeedURL($0.url) }
    }
}
