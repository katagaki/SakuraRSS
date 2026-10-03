import Foundation

extension RedditProvider: WebFeedProvider {

    public nonisolated static var providerID: String { "reddit" }

    public nonisolated static var domains: Set<String> { ["reddit.com"] }

    public nonisolated static func matchesFeedURL(_ feedURL: String) -> Bool {
        guard let url = URL(string: feedURL) else { return false }
        return RedditWebFeedURL(url: url) != nil
    }

    public nonisolated static func inferredSiteURL(fromFeedURL feedURL: String) -> String? {
        guard let url = URL(string: feedURL),
              matchesHost(url.host) else { return nil }
        if let page = RedditWebFeedURL(url: url) {
            return page.pageURL.absoluteString
        }
        guard url.path.lowercased().hasSuffix(".rss") else { return nil }
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

    public static func refresh(
        feed: Feed,
        on manager: FeedManager,
        options: FeedRefreshOptions
    ) async throws {
        try await manager.refreshRedditFeed(feed, options: options)
    }
}
