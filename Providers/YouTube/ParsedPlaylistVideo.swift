import Foundation

struct ParsedPlaylistVideo: Sendable {
    let videoId: String
    let title: String
    let thumbnailURL: String
    var publishedDate: Date?
}
