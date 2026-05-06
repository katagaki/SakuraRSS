import Foundation

extension InstagramProvider: MetadataProvider {

    nonisolated static func canFetchMetadata(for url: URL) -> Bool {
        isProfileURL(url)
    }

    static func fetchMetadata(for url: URL) async -> FetchedFeedMetadata? {
        guard let handle = extractIdentifier(from: url),
              let profileURL = profileURL(for: handle) else { return nil }
        let fetcher = InstagramProvider()
        fetcher.requestTimeoutInterval = 600
        let result = await fetcher.fetchProfile(profileURL: profileURL)
        return FetchedFeedMetadata(
            displayName: result.displayName,
            iconURL: result.profileImageURL.flatMap(URL.init(string:))
        )
    }
}
