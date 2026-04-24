import Foundation

/// Image URLs for a subreddit's recent posts, keyed by Reddit post ID.
struct RedditListingScrapeResult: Sendable {
    let imagesByPostID: [String: String]
}

/// Fetches `/r/<sub>/new.json` and extracts a best-available image URL
/// per post so RSS entries without a usable thumbnail can be filled in.
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
