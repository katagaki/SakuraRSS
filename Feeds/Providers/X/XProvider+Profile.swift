import Foundation

extension XProvider: ProfileFeedProvider {

    nonisolated static var providerID: String { "x" }

    nonisolated static var enabledFlagKey: String? { "Labs.XProfileFeeds" }

    nonisolated static var domains: Set<String> { ["x.com", "twitter.com"] }

    nonisolated static func discoveredFeed(forProfileURL url: URL) async -> DiscoveredFeed? {
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
