import Foundation

extension FeedManager {

    /// Fetches a subreddit's listing JSON once and returns a post-ID → image
    /// URL map used to populate `imageURL` for articles whose RSS entry
    /// didn't ship a usable thumbnail.
    nonisolated static func backfillRedditImages(
        forFeedURL feedURL: String
    ) async -> [String: String] {
        guard let url = URL(string: feedURL),
              let subreddit = RedditCommunityScraper.extractSubredditName(from: url) else {
            return [:]
        }
        let result = await RedditListingScraper.shared.scrapeListing(subreddit: subreddit)
        return result.imagesByPostID
    }

    /// Resolves the Reddit post ID from an article URL and looks it up in the
    /// listing-image map, returning `nil` when the URL isn't a Reddit comment
    /// link or the post wasn't in the listing window.
    nonisolated static func redditImageURL(
        for articleURL: String, in map: [String: String]
    ) -> String? {
        guard !map.isEmpty,
              let url = URL(string: articleURL),
              let postID = RedditPostScraper.postID(from: url) else {
            return nil
        }
        return map[postID]
    }
}
