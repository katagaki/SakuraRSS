import Foundation

extension FeedProviderRegistry {

    /// Providers whose feeds use a custom refresh pipeline.
    static let refreshable: [any RefreshableFeedProvider.Type] = [
        XProfileFetcher.self,
        InstagramProfileFetcher.self,
        YouTubePlaylistFetcher.self
    ]

    /// Returns the refreshable provider for a feed URL, or `nil` if none match
    /// (in which case the standard RSS pipeline runs).
    static func refreshableProvider(forFeedURL url: String) -> (any RefreshableFeedProvider.Type)? {
        refreshable.first { $0.matchesFeedURL(url) }
    }
}
