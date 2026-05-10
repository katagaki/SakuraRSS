import Foundation

extension XProvider: WebFeedProvider {

    static func refresh(
        feed: Feed,
        on manager: FeedManager,
        options: FeedRefreshOptions
    ) async throws {
        try await manager.refreshXFeed(
            feed,
            reloadData: options.reloadData,
            skipImagePreload: options.skipImagePreload,
            runNLP: options.runNLP,
            contentOnly: options.contentOnly
        )
    }
}
