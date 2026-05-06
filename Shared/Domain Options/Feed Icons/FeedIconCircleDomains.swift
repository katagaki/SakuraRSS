import Foundation

/// Domains whose feed icons should be displayed as circles (also skips trimming).
nonisolated enum FeedIconCircleDomains: DomainDefaults {

    static let exceptionDomains: Set<String> = [
        "x.com",
        "twitter.com",
        "bsky.app",
        "instagram.com",
        "pixelfed.social",
        "pixelfed.tokyo",
        "pixelfed.art",
        "youtube.com",
        "youtu.be",
        "note.com"
    ]

    static func shouldUseCircleIcon(feedDomain: String) -> Bool {
        matches(feedDomain: feedDomain)
    }
}
