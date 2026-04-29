import Foundation

extension YouTubePlaylistFetcher: ProfileFeedProvider {

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
}
