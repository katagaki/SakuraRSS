import Foundation

/// A provider whose feeds use a custom (non-RSS) refresh pipeline.
protocol WebFeedProvider: FeedProvider {

    static func refresh(
        feed: Feed,
        on manager: FeedManager,
        reloadData: Bool,
        skipImagePreload: Bool,
        runNLP: Bool
    ) async throws
}
