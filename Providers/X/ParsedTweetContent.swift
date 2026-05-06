import Foundation

/// Combined output of `XProvider.fetchTweetContent`. `focal` provides
/// the article header metadata; `threadItems` is the body in display order
struct ParsedTweetContent: Sendable {
    let focal: ParsedTweet
    let threadItems: [ParsedThreadItem]
}
