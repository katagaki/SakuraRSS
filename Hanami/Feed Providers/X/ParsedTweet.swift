import Foundation

public struct ParsedTweet: Sendable {
    public let id: String
    public let text: String
    public let author: String
    public let authorHandle: String
    public let url: String
    public let imageURL: String?
    public let carouselImageURLs: [String]
    public let publishedDate: Date?
    public let videoURL: String?
    public let videoAspectRatio: Double?
    public let videoThumbnailURL: String?
    public let videoIsGIF: Bool
}
