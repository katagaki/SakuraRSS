import Foundation

nonisolated struct Feed: Identifiable, Hashable, Sendable {
    let id: Int64
    var title: String
    var url: String
    var siteURL: String
    var feedDescription: String
    var faviconURL: String?
    var lastFetched: Date?
    var category: String?
    var isPodcast: Bool
    var isMuted: Bool
    var customIconURL: String?
    var acronymIcon: Data?
    /// `true` when the user has manually edited the feed's title; refreshes must not overwrite it.
    var isTitleCustomized: Bool

    var domain: String {
        URL(string: siteURL)?.host ?? URL(string: url)?.host ?? ""
    }

    var isVideoFeed: Bool {
        DisplayStyleVideoDomains.shouldPreferVideo(feedDomain: domain)
    }

    var isXFeed: Bool {
        XProfileScraper.isXFeedURL(url)
    }

    var isInstagramFeed: Bool {
        InstagramProfileScraper.isInstagramFeedURL(url)
    }

    var isYouTubePlaylistFeed: Bool {
        YouTubePlaylistScraper.isYouTubePlaylistFeedURL(url)
    }

    var isFeedViewDomain: Bool {
        isXFeed || isInstagramFeed
            || DisplayStyleFeedDomains.shouldPreferFeedView(feedDomain: domain) || hasMastodonFeedURL
    }

    var isFeedCompactViewDomain: Bool {
        DisplayStyleFeedCompactDomains.shouldPreferFeedCompactView(feedDomain: domain)
    }

    var isTimelineViewDomain: Bool {
        DisplayStyleTimelineDomains.shouldPreferTimeline(feedDomain: domain)
    }

    var isRedditFeed: Bool {
        let host = domain.lowercased()
        return host == "reddit.com" || host.hasSuffix(".reddit.com")
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

    var isPixelfedFeed: Bool {
        let host = domain.lowercased()
        return host == "pixelfed.social" || host.hasSuffix(".pixelfed.social")
            || host == "pixelfed.tokyo" || host.hasSuffix(".pixelfed.tokyo")
    }

    var isBlueskyFeed: Bool {
        let host = domain.lowercased()
        return host == "bsky.app" || host.hasSuffix(".bsky.app")
    }

    var isMastodonFeed: Bool {
        if hasMastodonFeedURL { return true }
        let host = domain.lowercased()
        let mastodonHosts: Set<String> = [
            "mastodon.social",
            "mastodon.online",
            "mastodon.world",
            "mstdn.social",
            "mstdn.jp",
            "fosstodon.org",
            "hachyderm.io",
            "infosec.exchange",
            "techhub.social",
            "mas.to"
        ]
        return mastodonHosts.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
    }

    var isCircleIcon: Bool {
        FaviconCircularDomains.shouldUseCircleIcon(feedDomain: domain)
    }

    var isPhotoViewDomain: Bool {
        DisplayStylePhotosDomains.shouldPreferPhotoView(feedDomain: domain)
    }

    var isSocialFeed: Bool {
        isXFeed || isInstagramFeed || isRedditFeed || isNoteFeed
            || isFeedViewDomain || isPhotoViewDomain
    }

    /// Feeds whose refresh path walks pages or runs a custom recipe.
    var isSlowRefreshFeed: Bool {
        isXFeed || isInstagramFeed || isYouTubePlaylistFeed || PetalRecipe.isPetalFeedURL(url)
    }

    var feedSection: FeedSection {
        if isPodcast { return .podcasts }
        if isXFeed { return .x }
        if isYouTubeFeed { return .youtube }
        if isInstagramFeed { return .instagram }
        if isPixelfedFeed { return .pixelfed }
        if isVimeoFeed { return .vimeo }
        if isNiconicoFeed { return .niconico }
        if isBlueskyFeed { return .bluesky }
        if isMastodonFeed { return .mastodon }
        if isRedditFeed { return .reddit }
        if isNoteFeed { return .note }
        return .feeds
    }

    /// Detects unlisted Mastodon instances via the /@username.rss URL pattern.
    private var hasMastodonFeedURL: Bool {
        guard let urlObj = URL(string: url) else { return false }
        let path = urlObj.path
        return path.hasPrefix("/@") && path.hasSuffix(".rss")
    }
}
