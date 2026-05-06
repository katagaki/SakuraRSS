import Foundation

extension RedditProvider: RSSFeedProvider {

    nonisolated static var providerID: String { "reddit" }

    nonisolated static var domains: Set<String> { ["reddit.com"] }

    nonisolated static func matchesFeedURL(_ feedURL: String) -> Bool {
        guard let url = URL(string: feedURL),
              matchesHost(url.host) else { return false }
        return url.path.lowercased().hasSuffix(".rss")
    }
}
