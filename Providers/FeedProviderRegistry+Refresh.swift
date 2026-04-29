import Foundation

extension FeedProviderRegistry {

    nonisolated static let refreshable: [any WebFeedProvider.Type] = [
        XProfileFetcher.self,
        InstagramProfileFetcher.self,
        YouTubePlaylistFetcher.self
    ]

    static func refreshableProvider(forFeedURL url: String) -> (any WebFeedProvider.Type)? {
        refreshable.first { $0.matchesFeedURL(url) }
    }
}
