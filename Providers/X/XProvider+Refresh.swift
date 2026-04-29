import Foundation

extension XProfileFetcher: WebFeedProvider {

    static func refresh(
        feed: Feed,
        on manager: FeedManager,
        reloadData: Bool,
        skipImagePreload: Bool,
        runNLP: Bool
    ) async throws {
        try await manager.refreshXFeed(
            feed,
            reloadData: reloadData,
            skipImagePreload: skipImagePreload,
            runNLP: runNLP
        )
    }
}
