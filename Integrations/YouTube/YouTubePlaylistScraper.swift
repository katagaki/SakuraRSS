import Foundation

struct ParsedPlaylistVideo: Sendable {
    let videoId: String
    let title: String
    let thumbnailURL: String
    var publishedDate: Date?
}

struct YouTubePlaylistScrapeResult: Sendable {
    let videos: [ParsedPlaylistVideo]
    let playlistTitle: String?
    let channelAvatarURL: String?
}

/// Scrapes YouTube playlist page HTML to list public videos.
final class YouTubePlaylistScraper {

    // MARK: - Static Helpers

    nonisolated static func isYouTubePlaylistURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let isYouTubeDomain = host == "youtube.com" || host == "www.youtube.com"
            || host == "m.youtube.com"
        guard isYouTubeDomain else { return false }
        guard url.path == "/playlist" || url.path == "/playlist/" else { return false }
        return extractPlaylistID(from: url) != nil
    }

    nonisolated static func extractPlaylistID(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        return components.queryItems?.first { $0.name == "list" }?.value
    }

    nonisolated static func feedURL(for playlistID: String) -> String {
        "youtube-playlist://\(playlistID)"
    }

    nonisolated static func playlistURL(for playlistID: String) -> URL? {
        URL(string: "https://www.youtube.com/playlist?list=\(playlistID)")
    }

    nonisolated static func isYouTubePlaylistFeedURL(_ url: String) -> Bool {
        url.hasPrefix("youtube-playlist://")
    }

    nonisolated static func playlistIDFromFeedURL(_ url: String) -> String? {
        guard isYouTubePlaylistFeedURL(url) else { return nil }
        return String(url.dropFirst("youtube-playlist://".count))
    }

    // MARK: - Public

    func scrapePlaylist(playlistID: String) async -> YouTubePlaylistScrapeResult {
        guard let url = Self.playlistURL(for: playlistID) else {
            return YouTubePlaylistScrapeResult(
                videos: [], playlistTitle: nil, channelAvatarURL: nil
            )
        }
        return await performFetch(url: url, playlistID: playlistID)
    }
}
