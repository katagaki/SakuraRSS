import Foundation

struct RedditCommunityScrapeResult: Sendable {
    let communityIconURL: String?
}

/// Fetches subreddit metadata from `/r/<name>/about.json`.
final class RedditCommunityScraper {

    // MARK: - Static Helpers

    nonisolated static func isRedditSubredditURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let isRedditDomain = host == "reddit.com" || host.hasSuffix(".reddit.com")
        guard isRedditDomain else { return false }
        return extractSubredditName(from: url) != nil
    }

    nonisolated static func extractSubredditName(from url: URL) -> String? {
        let components = url.pathComponents.filter { $0 != "/" }
        guard let rIndex = components.firstIndex(where: { $0.lowercased() == "r" }),
              rIndex + 1 < components.count else { return nil }
        let name = components[rIndex + 1]
        let cleaned = name.hasSuffix(".rss") ? String(name.dropLast(4)) : name
        return cleaned.isEmpty ? nil : cleaned
    }

    nonisolated static func aboutURL(for subreddit: String) -> URL? {
        URL(string: "https://www.reddit.com/r/\(subreddit)/about.json")
    }

    /// Reddit's `community_icon` signed query params aren't needed; stripping keeps cache keys stable.
    nonisolated static func stripQuery(from urlString: String) -> String {
        let decoded = urlString.replacingOccurrences(of: "&amp;", with: "&")
        guard var components = URLComponents(string: decoded) else { return decoded }
        components.query = nil
        return components.string ?? decoded
    }

    // MARK: - Public

    func scrapeCommunity(subreddit: String) async -> RedditCommunityScrapeResult {
        guard let url = Self.aboutURL(for: subreddit) else {
            return RedditCommunityScrapeResult(communityIconURL: nil)
        }
        return await performFetch(url: url)
    }
}
