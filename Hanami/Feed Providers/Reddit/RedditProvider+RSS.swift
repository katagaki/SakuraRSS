import Foundation

extension RedditProvider: RSSFeedProvider {

    public nonisolated static var providerID: String { "reddit" }

    public nonisolated static var domains: Set<String> { ["reddit.com"] }

    public nonisolated static func matchesFeedURL(_ feedURL: String) -> Bool {
        guard let url = URL(string: feedURL),
              matchesHost(url.host) else { return false }
        return url.path.lowercased().hasSuffix(".rss")
    }

    public nonisolated static func inferredSiteURL(fromFeedURL feedURL: String) -> String? {
        guard let url = URL(string: feedURL),
              matchesFeedURL(feedURL) else { return nil }
        if let subreddit = extractSubredditName(from: url) {
            return "https://www.reddit.com/r/\(subreddit)"
        }
        let segments = url.pathComponents.filter { $0 != "/" }
        if let userIndex = segments.firstIndex(where: { $0.lowercased() == "user" }),
           userIndex + 1 < segments.count {
            let raw = segments[userIndex + 1]
            let username = raw.hasSuffix(".rss") ? String(raw.dropLast(4)) : raw
            if !username.isEmpty {
                return "https://www.reddit.com/user/\(username)"
            }
        }
        return nil
    }
}
