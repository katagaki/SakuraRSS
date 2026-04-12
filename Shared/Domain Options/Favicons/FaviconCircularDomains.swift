import Foundation

/// Domains whose feed icons should be displayed as circles (e.g. profile photos).
/// Icons for these domains also skip blank-padding trimming automatically.
nonisolated enum FaviconCircularDomains {

    static let allowlistedDomains: Set<String> = [
        // X (Twitter)
        "x.com",
        "twitter.com",
        // Instagram
        "instagram.com",
        // Pixelfed
        "pixelfed.social",
        "pixelfed.tokyo",
        // YouTube
        "youtube.com",
        "youtu.be"
    ]

    static func shouldUseCircleIcon(feedDomain: String) -> Bool {
        let host = feedDomain.lowercased()
        return allowlistedDomains.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
    }
}
