import Foundation

public nonisolated struct Feed: Identifiable, Hashable, Sendable {
    public let id: Int64
    public var title: String
    public var url: String
    public var siteURL: String
    public var feedDescription: String
    public var iconURL: String?
    public var lastFetched: Date?
    public var category: String?
    public var isPodcast: Bool
    public var isMuted: Bool
    public var customIconURL: String?
    public var acronymIcon: Data?
    /// `true` when the user has manually edited the feed's title; refreshes must not overwrite it.
    public var isTitleCustomized: Bool
    /// Cached result of probing the feed's host for Fediverse `.well-known`
    /// endpoints. `nil` means the probe has not run yet.
    public var isFediverse: Bool?

    public var domain: String {
        URL(string: siteURL)?.host ?? URL(string: fetchURL)?.host ?? ""
    }

    /// The URL to fetch RSS from, with any `substack-feed://` marker stripped.
    public var fetchURL: String {
        SubstackAuth.unwrap(url)
    }

    public var isSubstackFeed: Bool {
        if SubstackAuth.isWrappedFeedURL(url) { return true }
        let host = (URL(string: url)?.host ?? "").lowercased()
        return host.hasSuffix(".substack.com")
    }

    public var isVideoFeed: Bool {
        DisplayStyleSetDomains.style(for: domain) == .video
    }

    public var isXFeed: Bool {
        XProvider.isFeedURL(url)
    }

    public var isInstagramFeed: Bool {
        InstagramProvider.isFeedURL(url)
    }

    public var isYouTubePlaylistFeed: Bool {
        YouTubePlaylistProvider.isFeedURL(url)
    }

    public var isFeedViewDomain: Bool {
        isXFeed || isInstagramFeed
            || DisplayStyleSetDomains.style(for: domain) == .feed
            || hasMastodonFeedURL
            || isFediverseFeed
    }

    public var isFeedCompactViewDomain: Bool {
        DisplayStyleSetDomains.style(for: domain) == .feedCompact
    }

    public var isTimelineViewDomain: Bool {
        DisplayStyleSetDomains.style(for: domain) == .timeline
    }

    public var isRedditFeed: Bool {
        let host = domain.lowercased()
        return host == "reddit.com" || host.hasSuffix(".reddit.com")
    }

    public var isHackerNewsFeed: Bool {
        let host = domain.lowercased()
        return host == HackerNewsProvider.host || host.hasSuffix(".\(HackerNewsProvider.host)")
    }

    public var isNoteFeed: Bool {
        let host = domain.lowercased()
        return host == "note.com" || host.hasSuffix(".note.com")
    }

    public var isYouTubeFeed: Bool {
        let host = domain.lowercased()
        return host == "youtube.com" || host.hasSuffix(".youtube.com")
            || host == "youtu.be" || host.hasSuffix(".youtu.be")
            || isYouTubePlaylistFeed
    }

    public var isVimeoFeed: Bool {
        let host = domain.lowercased()
        return host == "vimeo.com" || host.hasSuffix(".vimeo.com")
    }

    public var isNiconicoFeed: Bool {
        let host = domain.lowercased()
        return host == "nicovideo.jp" || host.hasSuffix(".nicovideo.jp")
    }

    public var isBlueskyFeed: Bool {
        let host = domain.lowercased()
        return host == "bsky.app" || host.hasSuffix(".bsky.app")
    }

    /// Hosts that are known to belong to the Fediverse without needing a probe,
    /// used as the fast-path before the cached `isFediverse` flag and any
    /// network detection.
    public var isKnownFediverseHost: Bool {
        if hasMastodonFeedURL { return true }
        let host = domain.lowercased()
        let knownHosts: Set<String> = [
            "mastodon.social",
            "mastodon.online",
            "mastodon.world",
            "mstdn.social",
            "mstdn.jp",
            "fosstodon.org",
            "hachyderm.io",
            "infosec.exchange",
            "techhub.social",
            "mas.to",
            "pixelfed.social",
            "pixelfed.tokyo",
            "pixelfed.art"
        ]
        return knownHosts.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
    }

    public var isFediverseFeed: Bool {
        if isKnownFediverseHost { return true }
        return isFediverse == true
    }

    /// True when this feed is served by a `ResearchFeedProvider` (e.g. arXiv).
    /// Used to exclude paper feeds from the headline summary pool.
    public var isResearchFeed: Bool {
        guard let provider = FeedProviderRegistry.provider(forFeedURL: url) else { return false }
        return provider is any ResearchFeedProvider.Type
    }

    public var isCircleIcon: Bool {
        FeedIconCircleDomains.shouldUseCircleIcon(feedDomain: domain)
    }

    public var isPhotoViewDomain: Bool {
        DisplayStyleSetDomains.style(for: domain) == .photos
    }

    public var isSocialFeed: Bool {
        isXFeed || isInstagramFeed || isRedditFeed || isNoteFeed
            || isFeedViewDomain || isPhotoViewDomain
    }

    /// Feeds whose refresh path walks pages or runs a custom recipe.
    public var isSlowRefreshFeed: Bool {
        isXFeed || isInstagramFeed || isYouTubePlaylistFeed || PetalRecipe.isPetalFeedURL(url)
    }

    public var isOPMLPortable: Bool {
        Feed.isOPMLPortableURL(url)
    }

    public static func isOPMLPortableURL(_ url: String) -> Bool {
        if XProvider.isFeedURL(url) { return false }
        if InstagramProvider.isFeedURL(url) { return false }
        if PetalRecipe.isPetalFeedURL(url) { return false }
        return true
    }

    public var feedSection: FeedSection {
        if isPodcast { return .podcasts }
        if isXFeed { return .x }
        if isYouTubeFeed { return .youtube }
        if isInstagramFeed { return .instagram }
        if isVimeoFeed { return .vimeo }
        if isNiconicoFeed { return .niconico }
        if isBlueskyFeed { return .bluesky }
        if isFediverseFeed { return .fediverse }
        if isRedditFeed { return .reddit }
        if isNoteFeed { return .note }
        if isSubstackFeed { return .substack }
        return .feeds
    }

    /// Detects unlisted Mastodon instances via the /@username.rss URL pattern.
    private var hasMastodonFeedURL: Bool {
        guard let urlObj = URL(string: url) else { return false }
        let path = urlObj.path
        return path.hasPrefix("/@") && path.hasSuffix(".rss")
    }
}
