import Foundation

/// Result of scraping a subreddit's `/r/<sub>/new.json` listing for per-post
/// image URLs.  Keyed by Reddit post ID (e.g. `1abcdef`).
struct RedditListingScrapeResult: Sendable {
    let imagesByPostID: [String: String]
}

/// Fetches a subreddit's public listing and extracts a best-available image
/// URL for each post.  Reddit's Atom feed often omits thumbnails entirely or
/// ships small `b.thumbs.redditmedia.com` URLs that 403 without a Referer
/// header, so one listing call backfills all posts for the current refresh.
final class RedditListingScraper: @unchecked Sendable {

    static let shared = RedditListingScraper()

    private init() {}

    nonisolated static func listingURL(for subreddit: String, limit: Int = 50) -> URL? {
        URL(string: "https://www.reddit.com/r/\(subreddit)/new.json?raw_json=1&limit=\(limit)")
    }

    func scrapeListing(subreddit: String) async -> RedditListingScrapeResult {
        guard let url = Self.listingURL(for: subreddit) else {
            return RedditListingScrapeResult(imagesByPostID: [:])
        }
        return await performFetch(url: url)
    }
}
