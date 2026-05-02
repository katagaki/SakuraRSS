import Foundation

/// Domains that opt into a specific display style by default.
nonisolated enum DisplayStyleSetDomains: DomainExceptions {

    static let domainStyles: [String: FeedDisplayStyle] = [
        "x.com": .feed,
        "twitter.com": .feed,
        "bsky.app": .feed,
        "mastodon.social": .feed,
        "mastodon.online": .feed,
        "mastodon.world": .feed,
        "mstdn.social": .feed,
        "mstdn.jp": .feed,
        "fosstodon.org": .feed,
        "hachyderm.io": .feed,
        "infosec.exchange": .feed,
        "techhub.social": .feed,
        "mas.to": .feed,
        "reddit.com": .feedCompact,
        "instagram.com": .photos,
        "pixelfed.social": .photos,
        "pixelfed.tokyo": .photos,
        "pixelfed.art": .photos,
        "pinterest.com": .masonry,
        "youtube.com": .video,
        "youtu.be": .video,
        "vimeo.com": .video,
        "nicovideo.jp": .video,
        "ch.nicovideo.jp": .video,
        "status.aws.amazon.com": .timeline,
        "status.dev.azure.com": .timeline,
        "rssfeed.azure.status.microsoft": .timeline,
        "status.cloud.google.com": .timeline,
        "status.firebase.google.com": .timeline,
        "githubstatus.com": .timeline,
        "status.gitlab.com": .timeline,
        "status.claude.com": .timeline,
        "www.cloudflarestatus.com": .timeline,
        "www.fastlystatus.com": .timeline,
        "www.akamaistatus.com": .timeline
    ]

    static let exceptionDomains: Set<String> = Set(domainStyles.keys)

    /// Returns the preferred display style for the given domain, or `nil` if none is set.
    static func style(for feedDomain: String) -> FeedDisplayStyle? {
        guard let matched = matchedDomain(for: feedDomain) else { return nil }
        return domainStyles[matched]
    }
}
