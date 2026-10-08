import Foundation

public extension FeedManager {

    /// Fetches one subreddit listing so articles whose RSS entry lacks a
    /// thumbnail (or only carries one gallery image) can be filled in.
    nonisolated static func fetchRedditImages(
        forFeedURL feedURL: String
    ) async -> RedditListingFetchResult {
        guard let url = URL(string: feedURL),
              let subreddit = RedditProvider.extractSubredditName(from: url) else {
            return RedditListingFetchResult(imagesByPostID: [:])
        }
        return await RedditProvider.shared.fetchListing(subreddit: subreddit)
    }

    nonisolated static func redditImageURL(
        for articleURL: String, in listing: RedditListingFetchResult
    ) -> String? {
        redditPostID(for: articleURL).flatMap { listing.imagesByPostID[$0] }
    }

    nonisolated static func redditGalleryImageURLs(
        for articleURL: String, in listing: RedditListingFetchResult
    ) -> [String] {
        redditPostID(for: articleURL).flatMap { listing.galleryImagesByPostID[$0] } ?? []
    }

    private nonisolated static func redditPostID(for articleURL: String) -> String? {
        guard let url = URL(string: articleURL) else { return nil }
        return RedditProvider.postID(from: url)
    }
}
