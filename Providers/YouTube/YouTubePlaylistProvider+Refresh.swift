import Foundation

extension YouTubePlaylistFetcher: RefreshableFeedProvider {

    static func refresh(
        feed: Feed,
        on manager: FeedManager,
        reloadData: Bool,
        skipImagePreload: Bool,
        runNLP: Bool
    ) async throws {
        try await manager.refreshYouTubePlaylistFeed(
            feed,
            reloadData: reloadData,
            skipImagePreload: skipImagePreload,
            runNLP: runNLP
        )
    }
}
