import Foundation

extension BlueskyProvider: ProfileFeedProvider {

    nonisolated static var providerID: String { "bluesky" }

    nonisolated static var domains: Set<String> { [host] }

    nonisolated static var feedURLScheme: String? { nil }

    nonisolated static func isProfileURL(_ url: URL) -> Bool {
        guard matchesHost(url.host) else { return false }
        let components = url.pathComponents.filter { $0 != "/" }
        guard components.count >= 2,
              components[0].lowercased() == "profile" else { return false }
        return isValidHandle(components[1])
    }

    nonisolated static func extractIdentifier(from url: URL) -> String? {
        guard matchesHost(url.host) else { return nil }
        let components = url.pathComponents.filter { $0 != "/" }
        guard components.count >= 2,
              components[0].lowercased() == "profile",
              isValidHandle(components[1]) else { return nil }
        return components[1]
    }

    nonisolated static func feedURL(for identifier: String) -> String {
        "https://bsky.app/profile/\(identifier)/rss"
    }

    nonisolated static func isFeedURL(_ url: String) -> Bool {
        guard let parsed = URL(string: url),
              matchesHost(parsed.host) else { return false }
        let components = parsed.pathComponents.filter { $0 != "/" }
        guard components.count == 3,
              components[0].lowercased() == "profile",
              components.last?.lowercased() == "rss" else { return false }
        return isValidHandle(components[1])
    }

    nonisolated static func identifierFromFeedURL(_ url: String) -> String? {
        guard isFeedURL(url),
              let parsed = URL(string: url) else { return nil }
        let components = parsed.pathComponents.filter { $0 != "/" }
        return components.count >= 2 ? components[1] : nil
    }

    /// Probes the constructed RSS URL to verify the user has RSS enabled
    /// before suggesting it.
    nonisolated static func discoveredFeed(forProfileURL url: URL) async -> DiscoveredFeed? {
        guard let handle = extractIdentifier(from: url) else { return nil }
        return await FeedDiscovery.probeFeedAt(domain: host, path: "/profile/\(handle)/rss")
    }
}
