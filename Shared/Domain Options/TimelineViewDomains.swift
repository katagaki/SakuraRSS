import Foundation

/// Domains that should use the timeline display style by default (e.g. status pages).
nonisolated enum TimelineViewDomains {

    static let allowlistedDomains: Set<String> = [
        "status.aws.amazon.com",
        "status.dev.azure.com",
        "rssfeed.azure.status.microsoft",
        "status.cloud.google.com",
        "status.firebase.google.com",
        "www.githubstatus.com",
        "status.gitlab.com",
        "status.claude.com",
        "www.cloudflarestatus.com",
        "www.fastlystatus.com",
        "www.akamaistatus.com"
    ]

    static func shouldPreferTimeline(feedDomain: String) -> Bool {
        let host = feedDomain.lowercased()
        return allowlistedDomains.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
    }
}
