import Foundation

struct ParsedPlaylistVideo: Sendable {
    let videoId: String
    let title: String
    let thumbnailURL: String
    var publishedDate: Date?
}

struct YouTubePlaylistFetchResult: Sendable {
    let videos: [ParsedPlaylistVideo]
    let playlistTitle: String?
    let channelAvatarURL: String?
}

/// Fetchs YouTube playlist page HTML to list public videos.
final class YouTubePlaylistFetcher: ProfileFetcher {

    // MARK: - ProfileFetcher

    nonisolated static var feedURLScheme: String? { "youtube-playlist" }

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

    // MARK: - Static Helpers

    nonisolated static func playlistURL(for playlistID: String) -> URL? {
        URL(string: "https://www.youtube.com/playlist?list=\(playlistID)")
    }

    // MARK: - Public

    func fetchPlaylist(playlistID: String) async -> YouTubePlaylistFetchResult {
        guard let url = Self.playlistURL(for: playlistID) else {
            return YouTubePlaylistFetchResult(
                videos: [], playlistTitle: nil, channelAvatarURL: nil
            )
        }
        return await performFetch(url: url, playlistID: playlistID)
    }
}
