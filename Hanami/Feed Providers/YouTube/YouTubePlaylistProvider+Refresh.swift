import Foundation

extension YouTubePlaylistProvider: WebFeedProvider {

    public static func refresh(
        feed: Feed,
        on manager: FeedManager,
        options: FeedRefreshOptions
    ) async throws {
        try await manager.refreshYouTubePlaylistFeed(
            feed,
            reloadData: options.reloadData,
            skipImagePreload: options.skipImagePreload,
            runNLP: options.runNLP,
            contentOnly: options.contentOnly
        )
    }
}
