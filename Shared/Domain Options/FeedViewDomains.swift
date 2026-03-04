import Foundation

/// Domains that should use the timeline display style by default.
nonisolated enum FeedViewDomains {

    static let allowlistedDomains: Set<String> = [
        "status.aws.amazon.com",
        "status.dev.azure.com",
        "rssfeed.azure.status.microsoft",
        "status.cloud.google.com",
        "www.githubstatus.com",
        "status.gitlab.com",
        "status.claude.com",
        // Bluesky
        "bsky.app",
        // Mastodon
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
