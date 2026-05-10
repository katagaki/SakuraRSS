import Foundation

/// Combined output of `XProvider.fetchTweetContent`. `focal` provides
/// the article header metadata; `threadItems` is the body in display order
public struct ParsedTweetContent: Sendable {
    public let focal: ParsedTweet
    public let threadItems: [ParsedThreadItem]
}
