import Foundation

extension XProvider: ProfileFeedProvider {

    public nonisolated static var providerID: String { "x" }

    public nonisolated static var enabledFlagKey: String? { "Labs.XProfileFeeds" }

    public nonisolated static var domains: Set<String> { ["x.com", "twitter.com"] }

    public nonisolated static func discoveredFeed(forProfileURL url: URL) async -> DiscoveredFeed? {
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
