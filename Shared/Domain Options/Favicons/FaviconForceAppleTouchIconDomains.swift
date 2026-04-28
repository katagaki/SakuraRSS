import Foundation

/// Domains whose favicon should be fetched directly from `/apple-touch-icon.png`.
nonisolated enum FaviconForceAppleTouchIconDomains: DomainExceptions {

    static let exceptionDomains: Set<String> = [
        "apple.com",
        "asahi.com",
        "claude.com",
        "ilpost.it",
        "microsoft.com"
    ]

    static func shouldForceAppleTouchIcon(feedDomain: String) -> Bool {
        matches(feedDomain: feedDomain)
    }
}
