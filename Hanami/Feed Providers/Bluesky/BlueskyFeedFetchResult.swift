import Foundation

public struct BlueskyFeedFetchResult: Sendable {
    public let posts: [ParsedBlueskyPost]
    public let displayName: String?
    public let profileImageURL: String?
}
