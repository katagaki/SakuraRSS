import Foundation

extension InstagramProvider: MetadataProvider {

    public nonisolated static func canFetchMetadata(for url: URL) -> Bool {
        isProfileURL(url)
    }

    public static func fetchMetadata(for url: URL) async -> FetchedFeedMetadata? {
        guard let handle = extractIdentifier(from: url),
              let profileURL = profileURL(for: handle) else { return nil }
        let fetcher = InstagramProvider()
        fetcher.requestTimeoutInterval = 600
        guard let result = try? await fetcher.fetchProfile(profileURL: profileURL) else { return nil }
        return FetchedFeedMetadata(
            displayName: result.displayName,
            iconURL: result.profileImageURL.flatMap(URL.init(string:))
        )
    }
}
