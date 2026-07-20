import Foundation

/// One tweet within a self-thread, used to build the article body. Carries
/// already-cleaned text (with leading thread mentions stripped), the post's
/// images in order, the post's video or GIF, and the URL of any quoted tweet.
public struct ParsedThreadItem: Sendable {
    public let id: String
    public let text: String
    public let imageURLs: [String]
    public let quotedTweetURL: String?
    public let videoURL: String?
    public let videoAspectRatio: Double?
    public let videoIsGIF: Bool
}
