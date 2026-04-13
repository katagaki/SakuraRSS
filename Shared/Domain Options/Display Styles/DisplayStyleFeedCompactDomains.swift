import Foundation

/// Domains that should use the feed (compact) display style by default.
nonisolated enum DisplayStyleFeedCompactDomains {

    static let allowlistedDomains: Set<String> = [
        "reddit.com"
    ]

    static func shouldPreferFeedCompactView(feedDomain: String) -> Bool {
        let host = feedDomain.lowercased()
        return allowlistedDomains.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
    }
}
