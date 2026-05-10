import Foundation

public struct XProfileFetchResult: Sendable {
    public let tweets: [ParsedTweet]
    public let profileImageURL: String?
    public let displayName: String?
}
