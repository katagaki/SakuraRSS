import Foundation

extension InstagramProvider: ProfileFeedProvider {

    nonisolated static var providerID: String { "instagram" }

    nonisolated static var enabledFlagKey: String? { "Labs.InstagramProfileFeeds" }

    nonisolated static var domains: Set<String> { ["instagram.com"] }

    nonisolated static func discoveredFeed(forProfileURL url: URL) async -> DiscoveredFeed? {
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
