import Foundation

struct YouTubePlaylistFetchResult: Sendable {
    let videos: [ParsedPlaylistVideo]
    let playlistTitle: String?
    let channelAvatarURL: String?
}
