import Foundation

extension NoteProfileFetcher: RSSFeedProvider {

    nonisolated static var providerID: String { "note" }

    nonisolated static func matchesFeedURL(_ feedURL: String) -> Bool {
        isFeedURL(feedURL)
    }
}

extension NoteProfileFetcher: MetadataFetchingProvider {

    nonisolated static func canFetchMetadata(for url: URL) -> Bool {
        isProfileURL(url)
    }

    static func fetchMetadata(for url: URL) async -> FetchedFeedMetadata? {
        guard let handle = extractIdentifier(from: url) else { return nil }
        let fetcher = NoteProfileFetcher()
        let result = await fetcher.fetchProfile(handle: handle)
        return FetchedFeedMetadata(
            displayName: result.displayName,
            iconURL: result.profileImageURL.flatMap(URL.init(string:))
        )
    }
}
