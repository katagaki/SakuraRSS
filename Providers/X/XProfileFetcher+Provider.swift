import Foundation

extension XProfileFetcher: ProfileFeedProvider, RefreshableFeedProvider {

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

    static func refresh(
        feed: Feed,
        on manager: FeedManager,
        reloadData: Bool,
        skipImagePreload: Bool,
        runNLP: Bool
    ) async throws {
        try await manager.refreshXFeed(
            feed,
            reloadData: reloadData,
            skipImagePreload: skipImagePreload,
            runNLP: runNLP
        )
    }
}
