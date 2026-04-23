import Foundation

/// Domains whose feed icons should be displayed as circles (also skips trimming).
nonisolated enum FaviconCircularDomains {

    static let allowlistedDomains: Set<String> = [
        "x.com",
        "twitter.com",
        "instagram.com",
        "pixelfed.social",
        "pixelfed.tokyo",
        "youtube.com",
        "youtu.be",
        "note.com"
    ]

    static func shouldUseCircleIcon(feedDomain: String) -> Bool {
        let host = feedDomain.lowercased()
        return allowlistedDomains.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
    }
}
