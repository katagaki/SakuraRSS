
import Foundation

extension FeedProviderRegistry {

    nonisolated static let refreshable: [any WebFeedProvider.Type] = [
        XProvider.self,
        InstagramProvider.self,
        YouTubePlaylistProvider.self
    ]

    static func refreshableProvider(forFeedURL url: String) -> (any WebFeedProvider.Type)? {
        refreshable.first { $0.matchesFeedURL(url) }
    }
}
