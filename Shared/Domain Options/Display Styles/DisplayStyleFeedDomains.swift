import Foundation

/// Domains that should use the feed display style by default (e.g. social media).
nonisolated enum DisplayStyleFeedDomains {

    static let allowlistedDomains: Set<String> = [
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
        let host = feedDomain.lowercased()
        return allowlistedDomains.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
    }
}
