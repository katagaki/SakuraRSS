import Foundation

extension SubstackPublicationFetcher: RSSFeedProvider {

    nonisolated static var providerID: String { "substack" }

    nonisolated static func matchesFeedURL(_ feedURL: String) -> Bool {
        isSubstackFeedURL(feedURL)
    }
}

extension SubstackPublicationFetcher: MetadataFetchingProvider {

    nonisolated static func canFetchMetadata(for url: URL) -> Bool {
        isSubstackPublicationURL(url)
    }

    nonisolated static var fallbackIconURL: URL? {
        URL(string: "https://substackcdn.com/icons/substack/apple-touch-icon.png")
    }

    /// Tries the public profile API (publication logo, then author photo),
    /// falling back to the publication API's `logo_url`.
    static func fetchMetadata(for url: URL) async -> FetchedFeedMetadata? {
        guard let host = url.host else { return nil }
        let fetcher = SubstackPublicationFetcher()

        if let logo = await fetcher.fetchPublicProfileLogo(host: host) {
            return FetchedFeedMetadata(displayName: nil, iconURL: logo.url,
                                       iconNeedsSquareCrop: logo.isAuthorPhoto)
        }

        let result = await fetcher.fetchPublication(host: host)
        if let logoURL = result.logoURL.flatMap(URL.init(string:)) {
            return FetchedFeedMetadata(displayName: nil, iconURL: logoURL)
        }

        return nil
    }
}
