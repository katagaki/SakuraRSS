import Foundation

/// Domains that host many distinct feeds under a single canonical host
/// (e.g. subreddits, HN tag feeds, RSSHub routes), so they should not be
/// treated as a single per-domain identity.
nonisolated enum FeedAggregatorDomains: DomainExceptions {

    static let exceptionDomains: Set<String> = [
        "reddit.com",
        "hnrss.org",
        "news.ycombinator.com"
    ]

    static func isFeedAggregator(feedDomain: String) -> Bool {
        matches(feedDomain: feedDomain)
    }

    static func isFeedAggregator(url: URL) -> Bool {
        matches(url: url)
    }
}
