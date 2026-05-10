import Foundation

extension RedditProvider: RSSFeedProvider {

    public nonisolated static var providerID: String { "reddit" }

    public nonisolated static var domains: Set<String> { ["reddit.com"] }

    public nonisolated static func matchesFeedURL(_ feedURL: String) -> Bool {
        guard let url = URL(string: feedURL),
              matchesHost(url.host) else { return false }
        return url.path.lowercased().hasSuffix(".rss")
    }
}
