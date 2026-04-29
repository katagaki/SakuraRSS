import Foundation

extension FeedProviderRegistry {

    nonisolated static let refreshable: [any RefreshableFeedProvider.Type] = [
        XProfileFetcher.self,
        InstagramProfileFetcher.self,
        YouTubePlaylistFetcher.self
    ]

    static func refreshableProvider(forFeedURL url: String) -> (any RefreshableFeedProvider.Type)? {
        refreshable.first { $0.matchesFeedURL(url) }
    }
}
