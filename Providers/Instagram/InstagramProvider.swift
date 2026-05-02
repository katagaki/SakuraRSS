import Foundation

extension InstagramProfileFetcher: ProfileFeedProvider {

    nonisolated static var providerID: String { "instagram" }

    nonisolated static var enabledFlagKey: String? { "Labs.InstagramProfileFeeds" }

    nonisolated static func discoveredFeed(forProfileURL url: URL) -> DiscoveredFeed? {
        guard isProfileURL(url),
              let handle = extractIdentifier(from: url) else {
            return nil
        }
        return DiscoveredFeed(
            title: "@\(handle)",
            url: feedURL(for: handle),
            siteURL: "https://www.instagram.com/\(handle)/"
        )
    }
}
