import Foundation

nonisolated struct Feed: Identifiable, Hashable, Sendable {
    let id: Int64
    var title: String
    var url: String
    var siteURL: String
    var feedDescription: String
    var iconURL: String?
    var lastFetched: Date?
    var category: String?
    var isPodcast: Bool
    var isMuted: Bool
    var customIconURL: String?
    var acronymIcon: Data?
    /// `true` when the user has manually edited the feed's title; refreshes must not overwrite it.
    var isTitleCustomized: Bool
    /// Cached result of probing the feed's host for Fediverse `.well-known`
    /// endpoints. `nil` means the probe has not run yet.
    var isFediverse: Bool?

    var domain: String {
        URL(string: siteURL)?.host ?? URL(string: fetchURL)?.host ?? ""
    }

    /// The URL to fetch RSS from, with any `substack-feed://` marker stripped.
    var fetchURL: String {
        SubstackAuth.unwrap(url)
    }

    var isSubstackFeed: Bool {
        if SubstackAuth.isWrappedFeedURL(url) { return true }
        let host = (URL(string: url)?.host ?? "").lowercased()
        return host.hasSuffix(".substack.com")
    }

    var isVideoFeed: Bool {
        DisplayStyleSetDomains.style(for: domain) == .video
    }

    var isXFeed: Bool {
        XProfileFetcher.isFeedURL(url)
    }

    var isInstagramFeed: Bool {
        InstagramProfileFetcher.isFeedURL(url)
    }

    var isYouTubePlaylistFeed: Bool {
        YouTubePlaylistFetcher.isFeedURL(url)
    }

    var isFeedViewDomain: Bool {
        isXFeed || isInstagramFeed
            || DisplayStyleSetDomains.style(for: domain) == .feed
            || hasMastodonFeedURL
            || isFediverseFeed
    }

    var isFeedCompactViewDomain: Bool {
        DisplayStyleSetDomains.style(for: domain) == .feedCompact
    }

    var isTimelineViewDomain: Bool {
        DisplayStyleSetDomains.style(for: domain) == .timeline
    }

    var isRedditFeed: Bool {
        let host = domain.lowercased()
        return host == "reddit.com" || host.hasSuffix(".reddit.com")
    }

    var isHackerNewsFeed: Bool {
        let host = domain.lowercased()
        return host == HackerNewsProvider.host || host.hasSuffix(".\(HackerNewsProvider.host)")
    }

    var isNoteFeed: Bool {
        let host = domain.lowercased()
        return host == "note.com" || host.hasSuffix(".note.com")
    }

    var isYouTubeFeed: Bool {
        let host = domain.lowercased()
        return host == "youtube.com" || host.hasSuffix(".youtube.com")
            || host == "youtu.be" || host.hasSuffix(".youtu.be")
            || isYouTubePlaylistFeed
    }

    var isVimeoFeed: Bool {
        let host = domain.lowercased()
        return host == "vimeo.com" || host.hasSuffix(".vimeo.com")
    }

    var isNiconicoFeed: Bool {
        let host = domain.lowercased()
        return host == "nicovideo.jp" || host.hasSuffix(".nicovideo.jp")
    }

    var isBlueskyFeed: Bool {
        let host = domain.lowercased()
        return host == "bsky.app" || host.hasSuffix(".bsky.app")
    }

    /// Hosts that are known to belong to the Fediverse without needing a probe,
    /// used as the fast-path before the cached `isFediverse` flag and any
    /// network detection.
    var isKnownFediverseHost: Bool {
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

    var isFediverseFeed: Bool {
        if isKnownFediverseHost { return true }
        return isFediverse == true
    }

    var isCircleIcon: Bool {
        FeedIconCircleDomains.shouldUseCircleIcon(feedDomain: domain)
    }

    var isPhotoViewDomain: Bool {
        DisplayStyleSetDomains.style(for: domain) == .photos
    }

    var isSocialFeed: Bool {
        isXFeed || isInstagramFeed || isRedditFeed || isNoteFeed
            || isFeedViewDomain || isPhotoViewDomain
    }

    /// Feeds whose refresh path walks pages or runs a custom recipe.
    var isSlowRefreshFeed: Bool {
        isXFeed || isInstagramFeed || isYouTubePlaylistFeed || PetalRecipe.isPetalFeedURL(url)
    }

    var isOPMLPortable: Bool {
        Feed.isOPMLPortableURL(url)
    }

    static func isOPMLPortableURL(_ url: String) -> Bool {
        if XProfileFetcher.isFeedURL(url) { return false }
        if InstagramProfileFetcher.isFeedURL(url) { return false }
        if PetalRecipe.isPetalFeedURL(url) { return false }
        return true
    }

    var feedSection: FeedSection {
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
