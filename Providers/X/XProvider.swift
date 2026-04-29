import Foundation

extension XProfileFetcher: ProfileFeedProvider {

    nonisolated static var providerID: String { "x" }

    nonisolated static var labsFlagKey: String? { "Labs.XProfileFeeds" }

    nonisolated static func discoveredFeed(forProfileURL url: URL) -> DiscoveredFeed? {
        guard isProfileURL(url),
              let handle = extractIdentifier(from: url) else {
            return nil
        }
        return DiscoveredFeed(
            title: "@\(handle)",
            url: feedURL(for: handle),
            siteURL: "https://x.com/\(handle)"
        )
    }
}
