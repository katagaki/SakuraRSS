import Foundation

/// A provider whose feeds derive from a profile/community/playlist URL.
protocol ProfileFeedProvider: FeedProvider, FetchesProfile {

    nonisolated static func discoveredFeed(forProfileURL url: URL) -> DiscoveredFeed?
}

extension ProfileFeedProvider {

    nonisolated static func matchesFeedURL(_ feedURL: String) -> Bool {
        isFeedURL(feedURL)
    }
}
