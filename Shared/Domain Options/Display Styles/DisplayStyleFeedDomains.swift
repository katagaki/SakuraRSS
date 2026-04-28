import Foundation

/// Domains that should use the feed display style by default (e.g. social media).
nonisolated enum DisplayStyleFeedDomains: DomainExceptions {

    static let exceptionDomains: Set<String> = [
        "x.com",
        "twitter.com",
        "bsky.app",
        "mastodon.social",
        "mastodon.online",
        "mastodon.world",
        "mstdn.social",
        "mstdn.jp",
        "fosstodon.org",
        "hachyderm.io",
        "infosec.exchange",
        "techhub.social",
        "mas.to"
    ]

    static func shouldPreferFeedView(feedDomain: String) -> Bool {
        matches(feedDomain: feedDomain)
    }
}
