import Foundation

extension RedditProvider: MetadataProvider {

    nonisolated static func canFetchMetadata(for url: URL) -> Bool {
        isRedditSubredditURL(url)
    }

    static func fetchMetadata(for url: URL) async -> FetchedFeedMetadata? {
        guard let subreddit = extractSubredditName(from: url) else { return nil }
        let result = await RedditProvider.shared.fetchCommunity(subreddit: subreddit)
        return FetchedFeedMetadata(
            displayName: nil,
            iconURL: result.communityIconURL.flatMap(URL.init(string:))
        )
    }
}
