import Foundation

/// Parsed video from a YouTube playlist page.
struct ParsedPlaylistVideo: Sendable {
    let videoId: String
    let title: String
    let thumbnailURL: String
    var publishedDate: Date?
}

/// Result of scraping a YouTube playlist.
struct YouTubePlaylistScrapeResult: Sendable {
    let videos: [ParsedPlaylistVideo]
    let playlistTitle: String?
    let channelAvatarURL: String?
}

/// Fetches videos from a YouTube playlist by scraping the playlist page HTML.
/// No login required - playlists are public.
final class YouTubePlaylistScraper {

    // MARK: - Static Helpers

    /// Returns true if the URL points to a YouTube playlist.
    nonisolated static func isYouTubePlaylistURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let isYouTubeDomain = host == "youtube.com" || host == "www.youtube.com"
            || host == "m.youtube.com"
        guard isYouTubeDomain else { return false }
        guard url.path == "/playlist" || url.path == "/playlist/" else { return false }
        return extractPlaylistID(from: url) != nil
    }

    /// Extracts the playlist ID from a YouTube playlist URL.
    nonisolated static func extractPlaylistID(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        return components.queryItems?.first { $0.name == "list" }?.value
    }

    /// The pseudo-feed URL stored in the database for a YouTube playlist.
    nonisolated static func feedURL(for playlistID: String) -> String {
        "youtube-playlist://\(playlistID)"
    }

    /// Constructs the canonical YouTube playlist URL from a playlist ID.
    nonisolated static func playlistURL(for playlistID: String) -> URL? {
        URL(string: "https://www.youtube.com/playlist?list=\(playlistID)")
    }

    /// Checks if a feed URL is a YouTube playlist pseudo-feed.
    nonisolated static func isYouTubePlaylistFeedURL(_ url: String) -> Bool {
        url.hasPrefix("youtube-playlist://")
    }

    /// Extracts the playlist ID from a YouTube playlist pseudo-feed URL.
    nonisolated static func playlistIDFromFeedURL(_ url: String) -> String? {
        guard isYouTubePlaylistFeedURL(url) else { return nil }
        return String(url.dropFirst("youtube-playlist://".count))
    }

    // MARK: - Public

    /// Fetches videos from the given YouTube playlist.
    func scrapePlaylist(playlistID: String) async -> YouTubePlaylistScrapeResult {
        guard let url = Self.playlistURL(for: playlistID) else {
            return YouTubePlaylistScrapeResult(
                videos: [], playlistTitle: nil, channelAvatarURL: nil
            )
        }
        return await performFetch(url: url, playlistID: playlistID)
    }
}
