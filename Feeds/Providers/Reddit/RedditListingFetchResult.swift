import Foundation

/// Image URLs for a subreddit's recent posts, keyed by Reddit post ID.
struct RedditListingFetchResult: Sendable {
    let imagesByPostID: [String: String]
}
