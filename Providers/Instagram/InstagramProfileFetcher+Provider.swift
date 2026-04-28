import Foundation

extension InstagramProfileFetcher: ProfileFeedProvider, RefreshableFeedProvider {

    nonisolated static var providerID: String { "instagram" }

    nonisolated static var labsFlagKey: String? { "Labs.InstagramProfileFeeds" }

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

    static func refresh(
        feed: Feed,
        on manager: FeedManager,
        reloadData: Bool,
        skipImagePreload: Bool,
        runNLP: Bool
    ) async throws {
        try await manager.refreshInstagramFeed(
            feed,
            reloadData: reloadData,
            skipImagePreload: skipImagePreload,
            runNLP: runNLP
        )
    }
}
