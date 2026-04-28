import Foundation

/// Domains that should use the feed (compact) display style by default.
nonisolated enum DisplayStyleFeedCompactDomains: DomainExceptions {

    static let exceptionDomains: Set<String> = [
        "reddit.com"
    ]

    static func shouldPreferFeedCompactView(feedDomain: String) -> Bool {
        matches(feedDomain: feedDomain)
    }
}
