import Foundation

/// Result of scraping a subreddit's public `about.json` endpoint.
struct RedditCommunityScrapeResult: Sendable {
    let communityIconURL: String?
}

/// Fetches subreddit metadata (currently just the community icon) from
/// Reddit's public `/r/<name>/about.json` endpoint. No login required.
final class RedditCommunityScraper {

    // MARK: - Static Helpers

    /// Returns true if the URL points to a subreddit on reddit.com.
    nonisolated static func isRedditSubredditURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let isRedditDomain = host == "reddit.com" || host.hasSuffix(".reddit.com")
        guard isRedditDomain else { return false }
        return extractSubredditName(from: url) != nil
    }

    /// Extracts the subreddit name from a URL like
    /// `https://www.reddit.com/r/iosbeta/` or `.../r/iosbeta/.rss`.
    nonisolated static func extractSubredditName(from url: URL) -> String? {
        let components = url.pathComponents.filter { $0 != "/" }
        guard let rIndex = components.firstIndex(where: { $0.lowercased() == "r" }),
              rIndex + 1 < components.count else { return nil }
        let name = components[rIndex + 1]
        let cleaned = name.hasSuffix(".rss") ? String(name.dropLast(4)) : name
        return cleaned.isEmpty ? nil : cleaned
    }

    /// Constructs the `about.json` URL for a subreddit.
    nonisolated static func aboutURL(for subreddit: String) -> URL? {
        URL(string: "https://www.reddit.com/r/\(subreddit)/about.json")
    }

    /// Removes the query string from a URL string, leaving scheme + host + path.
    /// Reddit's `community_icon` includes signed query params that aren't
    /// required for the image to load; stripping keeps cache keys stable.
    nonisolated static func stripQuery(from urlString: String) -> String {
        let decoded = urlString.replacingOccurrences(of: "&amp;", with: "&")
        guard var components = URLComponents(string: decoded) else { return decoded }
        components.query = nil
        return components.string ?? decoded
    }

    // MARK: - Public

    /// Fetches the community icon URL for the given subreddit.
    func scrapeCommunity(subreddit: String) async -> RedditCommunityScrapeResult {
        guard let url = Self.aboutURL(for: subreddit) else {
            return RedditCommunityScrapeResult(communityIconURL: nil)
        }
        return await performFetch(url: url)
    }
}
