import Foundation

extension RedditCommunityFetcher: RSSFeedProvider {

    nonisolated static var providerID: String { "reddit" }

    nonisolated static func matchesFeedURL(_ feedURL: String) -> Bool {
        guard let url = URL(string: feedURL),
              let host = url.host?.lowercased() else { return false }
        let isRedditHost = host == "reddit.com"
            || host.hasSuffix(".reddit.com")
        guard isRedditHost else { return false }
        return url.path.lowercased().hasSuffix(".rss")
    }
}

extension RedditCommunityFetcher: MetadataFetchingProvider {

    nonisolated static func canFetchMetadata(for url: URL) -> Bool {
        isRedditSubredditURL(url)
    }

    static func fetchMetadata(for url: URL) async -> FetchedFeedMetadata? {
        guard let subreddit = extractSubredditName(from: url) else { return nil }
        let fetcher = RedditCommunityFetcher()
        let result = await fetcher.fetchCommunity(subreddit: subreddit)
        return FetchedFeedMetadata(
            displayName: nil,
            iconURL: result.communityIconURL.flatMap(URL.init(string:))
        )
    }
}
