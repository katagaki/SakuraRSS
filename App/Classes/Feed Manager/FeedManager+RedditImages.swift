import Foundation

extension FeedManager {

    /// Fetches one subreddit listing and returns a post-ID → image URL
    /// map for articles whose RSS entry lacks a thumbnail.
    nonisolated static func fetchRedditImages(
        forFeedURL feedURL: String
    ) async -> [String: String] {
        guard let url = URL(string: feedURL),
              let subreddit = RedditCommunityFetcher.extractSubredditName(from: url) else {
            return [:]
        }
        let result = await RedditListingFetcher.shared.fetchListing(subreddit: subreddit)
        return result.imagesByPostID
    }

    /// Looks up the listing-image URL for an article by its Reddit post ID.
    nonisolated static func redditImageURL(
        for articleURL: String, in map: [String: String]
    ) -> String? {
        guard !map.isEmpty,
              let url = URL(string: articleURL),
              let postID = RedditPostFetcher.postID(from: url) else {
            return nil
        }
        return map[postID]
    }
}
