import Foundation

extension InstagramProfileFetcher: WebFeedProvider {

    static func refresh(
        feed: Feed,
        on manager: FeedManager,
        reloadData: Bool,
        skipImagePreload: Bool,
        runNLP: Bool,
        contentOnly: Bool
    ) async throws {
        try await manager.refreshInstagramFeed(
            feed,
            reloadData: reloadData,
            skipImagePreload: skipImagePreload,
            runNLP: runNLP,
            contentOnly: contentOnly
        )
    }
}
