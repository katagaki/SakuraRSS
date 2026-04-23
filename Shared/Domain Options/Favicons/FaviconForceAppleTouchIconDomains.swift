import Foundation

/// Domains whose favicon should be fetched directly from `/apple-touch-icon.png`.
nonisolated enum FaviconForceAppleTouchIconDomains {

    static let allowlistedDomains: Set<String> = [
        "apple.com",
        "asahi.com",
        "claude.com",
        "ilpost.it",
        "microsoft.com"
    ]

    static func shouldForceAppleTouchIcon(feedDomain: String) -> Bool {
        let host = feedDomain.lowercased()
        return allowlistedDomains.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
    }
}
