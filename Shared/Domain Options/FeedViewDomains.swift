import Foundation

/// Domains that should use the feed display style by default.
nonisolated enum FeedViewDomains {

    static let allowlistedDomains: Set<String> = [
        "status.aws.amazon.com",
        "status.dev.azure.com",
        "rssfeed.azure.status.microsoft",
        "status.cloud.google.com",
        "www.githubstatus.com",
        "status.gitlab.com",
        "status.claude.com"
    ]

    static func shouldPreferFeedView(feedDomain: String) -> Bool {
        let host = feedDomain.lowercased()
        return allowlistedDomains.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
    }
}
