import Foundation

extension YouTubePlaylistFetcher: ProfileFeedProvider, RefreshableFeedProvider {

    nonisolated static var providerID: String { "youtube-playlist" }

    nonisolated static func discoveredFeed(forProfileURL url: URL) -> DiscoveredFeed? {
        guard isProfileURL(url),
              let playlistID = extractIdentifier(from: url) else {
            return nil
        }
        return DiscoveredFeed(
            title: "YouTube Playlist",
            url: feedURL(for: playlistID),
            siteURL: "https://www.youtube.com/playlist?list=\(playlistID)"
        )
    }

    static func refresh(
        feed: Feed,
        on manager: FeedManager,
        reloadData: Bool,
        skipImagePreload: Bool,
        runNLP: Bool
    ) async throws {
        try await manager.refreshYouTubePlaylistFeed(
            feed,
            reloadData: reloadData,
            skipImagePreload: skipImagePreload,
            runNLP: runNLP
        )
    }
}
