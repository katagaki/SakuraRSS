import Foundation

/// Domains whose favicon should be fetched directly from
/// `/apple-touch-icon.png` rather than going through the normal PWA /
/// FaviconFinder pipeline.  Some sites (e.g. Microsoft) serve a pale
/// favicon.ico and a masked manifest icon, while the apple-touch-icon
/// is the only richly-colored logo.
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
