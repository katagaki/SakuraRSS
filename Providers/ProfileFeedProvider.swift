import Foundation

/// A provider whose feeds derive from a user-visible profile/community page
/// (handle, playlist ID, subreddit name).
///
/// `FetchesProfile` already supplies `isProfileURL`, `extractIdentifier`,
/// `feedURL(for:)`, `isFeedURL`, and `identifierFromFeedURL`. Conformers add
/// only the discovery shape (`discoveredFeed(forProfileURL:)`).
protocol ProfileFeedProvider: FeedProvider, FetchesProfile {

    /// Builds a `DiscoveredFeed` for a matching profile URL, or `nil`.
    nonisolated static func discoveredFeed(forProfileURL url: URL) -> DiscoveredFeed?
}

extension ProfileFeedProvider {

    nonisolated static func matchesFeedURL(_ feedURL: String) -> Bool {
        isFeedURL(feedURL)
    }
}
