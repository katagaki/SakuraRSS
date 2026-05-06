import Foundation

extension BlueskyProvider: MetadataProvider {

    nonisolated static func canFetchMetadata(for url: URL) -> Bool {
        isProfileURL(url)
    }

    static func fetchMetadata(for url: URL) async -> FetchedFeedMetadata? {
        guard let handle = extractIdentifier(from: url) else { return nil }
        let fetcher = BlueskyProvider()
        let result = await fetcher.fetchProfile(handle: handle)
        return FetchedFeedMetadata(
            displayName: result.displayName,
            iconURL: result.profileImageURL.flatMap(URL.init(string:))
        )
    }
}
