import Foundation

public struct ParsedBlueskyImage: Sendable {
    public let thumbURL: String
    public let fullsizeURL: String
    public let alt: String
}

public struct ParsedBlueskyPost: Sendable {
    public let uri: String
    public let url: String
    public let text: String
    public let author: String
    public let authorHandle: String
    public let images: [ParsedBlueskyImage]
    public let videoThumbnailURL: String?
    public let publishedDate: Date?
}
