import Foundation

extension XProfileFetcher: MetadataFetchingProvider {

    nonisolated static func canFetchMetadata(for url: URL) -> Bool {
        isProfileURL(url)
    }

    static func fetchMetadata(for url: URL) async -> FetchedFeedMetadata? {
        guard let handle = extractIdentifier(from: url) else { return nil }
        let fetcher = XProfileFetcher()
        fetcher.requestTimeoutInterval = 600
        guard let cookies = await Self.getXCookies(),
              let userInfo = await fetcher.fetchUserInfo(
                  screenName: handle, cookies: cookies
              ) else { return nil }
        return FetchedFeedMetadata(
            displayName: userInfo.displayName,
            iconURL: userInfo.profileImageURL.flatMap(URL.init(string:))
        )
    }
}
