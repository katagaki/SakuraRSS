import Foundation

extension YouTubePlaylistProvider: ProfileFeedProvider {

    nonisolated static var providerID: String { "youtube-playlist" }

    nonisolated static var domains: Set<String> { ["youtube.com"] }

    nonisolated static var feedURLScheme: String? { "youtube-playlist" }

    /// Stricter than `matchesHost` — playlist pages are only served on
    /// bare/`www.`/`m.` subdomains.
    nonisolated static func isProfileURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let isYouTubeDomain = host == "youtube.com" || host == "www.youtube.com"
            || host == "m.youtube.com"
        guard isYouTubeDomain else { return false }
        guard url.path == "/playlist" || url.path == "/playlist/" else { return false }
        return extractIdentifier(from: url) != nil
    }

    nonisolated static func extractIdentifier(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        return components.queryItems?.first { $0.name == "list" }?.value
    }

    nonisolated static func feedURL(for identifier: String) -> String {
        "youtube-playlist://\(identifier)"
    }

    nonisolated static func discoveredFeed(forProfileURL url: URL) async -> DiscoveredFeed? {
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
