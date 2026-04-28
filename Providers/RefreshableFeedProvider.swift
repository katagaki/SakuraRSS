import Foundation

/// A provider whose feeds use a custom (non-RSS) refresh pipeline.
///
/// `FeedManager+Refresh` dispatches through this protocol when a feed's URL
/// matches a refreshable provider, so adding a new pseudo-feed source is just
/// a matter of conforming a new fetcher.
protocol RefreshableFeedProvider: FeedProvider {

    static func refresh(
        feed: Feed,
        on manager: FeedManager,
        reloadData: Bool,
        skipImagePreload: Bool,
        runNLP: Bool
    ) async throws
}
