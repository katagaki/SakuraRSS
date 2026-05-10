import Foundation

/// One tweet within a self-thread, used to build the article body. Carries
/// already-cleaned text (with leading thread mentions stripped), the post's
/// images in order, and the URL of any quoted tweet.
struct ParsedThreadItem: Sendable {
    let id: String
    let text: String
    let imageURLs: [String]
    let quotedTweetURL: String?
}
