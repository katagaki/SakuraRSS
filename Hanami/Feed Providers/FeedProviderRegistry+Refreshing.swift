import Foundation

public extension FeedProviderRegistry {

    nonisolated(unsafe) static let refreshable: [any WebFeedProvider.Type] = [
        XProvider.self,
        InstagramProvider.self,
        YouTubePlaylistProvider.self,
        BlueskyProvider.self
    ]

    static func refreshableProvider(forFeedURL url: String) -> (any WebFeedProvider.Type)? {
        refreshable.first { $0.matchesFeedURL(url) }
    }
}
