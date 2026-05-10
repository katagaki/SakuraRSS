import Foundation

public struct YouTubePlaylistFetchResult: Sendable {
    public let videos: [ParsedPlaylistVideo]
    public let playlistTitle: String?
    public let channelAvatarURL: String?
}
