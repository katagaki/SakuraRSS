import Foundation

/// Domains whose feeds primarily link out to other domains
/// (e.g. Reddit subreddits, Hacker News, hnrss.org), so each item's
/// "true" article URL may live on a different host than the feed item URL.
nonisolated enum LinkAggregatorDomains: DomainExceptions {

    static let exceptionDomains: Set<String> = [
        "reddit.com",
        "hnrss.org",
        "news.ycombinator.com"
    ]

    static func isLinkAggregator(feedDomain: String) -> Bool {
        matches(feedDomain: feedDomain)
    }

    static func isLinkAggregator(url: URL) -> Bool {
        matches(url: url)
    }
}
