import Foundation

/// Domains whose feed icons should be displayed as circles (also skips trimming).
public nonisolated enum FeedIconCircleDomains: DomainDefaults {

    public static let exceptionDomains: Set<String> = [
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

    public static func shouldUseCircleIcon(feedDomain: String) -> Bool {
        matches(feedDomain: feedDomain)
    }
}
