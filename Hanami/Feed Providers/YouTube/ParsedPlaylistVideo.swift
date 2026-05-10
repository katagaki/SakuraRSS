import Foundation

public struct ParsedPlaylistVideo: Sendable {
    public let videoId: String
    public let title: String
    public let thumbnailURL: String
    public var publishedDate: Date?
}
