import Foundation

/// Domains whose feed icons should be displayed as circles (also skips trimming).
nonisolated enum FaviconCircularDomains: DomainExceptions {

    static let exceptionDomains: Set<String> = [
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
        matches(feedDomain: feedDomain)
    }
}
