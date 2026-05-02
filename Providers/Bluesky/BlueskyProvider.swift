import Foundation

extension BlueskyProfileFetcher: RSSFeedProvider {

    nonisolated static var providerID: String { "bluesky" }

    nonisolated static func matchesFeedURL(_ feedURL: String) -> Bool {
        isFeedURL(feedURL)
    }
}

extension BlueskyProfileFetcher: MetadataFetchingProvider {

    nonisolated static func canFetchMetadata(for url: URL) -> Bool {
        isProfileURL(url)
    }

    static func fetchMetadata(for url: URL) async -> FetchedFeedMetadata? {
        guard let handle = extractIdentifier(from: url) else { return nil }
        let fetcher = BlueskyProfileFetcher()
        let result = await fetcher.fetchProfile(handle: handle)
        return FetchedFeedMetadata(
            displayName: result.displayName,
            iconURL: result.profileImageURL.flatMap(URL.init(string:))
        )
    }
}
