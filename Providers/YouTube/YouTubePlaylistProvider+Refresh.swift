import Foundation

extension YouTubePlaylistFetcher: WebFeedProvider {

    static func refresh(
        feed: Feed,
        on manager: FeedManager,
        reloadData: Bool,
        skipImagePreload: Bool,
        runNLP: Bool,
        contentOnly: Bool
    ) async throws {
        try await manager.refreshYouTubePlaylistFeed(
            feed,
            reloadData: reloadData,
            skipImagePreload: skipImagePreload,
            runNLP: runNLP,
            contentOnly: contentOnly
        )
    }
}
