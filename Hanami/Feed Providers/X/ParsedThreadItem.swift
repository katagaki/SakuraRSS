import Foundation

/// One tweet within a self-thread, used to build the article body. Carries
/// already-cleaned text (with leading thread mentions stripped), the post's
/// images in order, and the URL of any quoted tweet.
public struct ParsedThreadItem: Sendable {
    public let id: String
    public let text: String
    public let imageURLs: [String]
    public let quotedTweetURL: String?
}
