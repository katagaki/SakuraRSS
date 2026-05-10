import Foundation

/// Image URLs for a subreddit's recent posts, keyed by Reddit post ID.
public struct RedditListingFetchResult: Sendable {
    public let imagesByPostID: [String: String]
}
