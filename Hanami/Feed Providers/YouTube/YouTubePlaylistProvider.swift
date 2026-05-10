import Foundation

/// Fetchs YouTube playlist page HTML to list public videos.
public final class YouTubePlaylistProvider {
    public nonisolated static func playlistURL(for playlistID: String) -> URL? {
        URL(string: "https://www.youtube.com/playlist?list=\(playlistID)")
    }
    public func fetchPlaylist(playlistID: String) async -> YouTubePlaylistFetchResult {
        guard let url = Self.playlistURL(for: playlistID) else {
            return YouTubePlaylistFetchResult(
                videos: [], playlistTitle: nil, channelAvatarURL: nil
            )
        }
        return await performFetch(url: url, playlistID: playlistID)
    }
}
