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
    /// `true` when the user has manually edited the feed's title.
    /// Refreshes must not overwrite a customized title with whatever the
    /// remote feed currently advertises.
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

    var isCircleIcon: Bool {
        FaviconCircularDomains.shouldUseCircleIcon(feedDomain: domain)
    }

    var isPhotoViewDomain: Bool {
        DisplayStylePhotosDomains.shouldPreferPhotoView(feedDomain: domain)
    }

    var isSocialFeed: Bool {
        isXFeed || isInstagramFeed || isRedditFeed || isFeedViewDomain || isPhotoViewDomain
    }

    /// Feeds whose refresh path is slow because it walks paginated pages
    /// (X, Instagram), scrapes HTML (YouTube playlists), or runs a custom
    /// recipe (Petal).  Prioritized ahead of regular RSS feeds so the
    /// wall-clock refresh is bounded by the slowest bucket, not by where
    /// slow feeds happen to land in the feed list.
    var isSlowRefreshFeed: Bool {
        isXFeed || isInstagramFeed || isYouTubePlaylistFeed || PetalRecipe.isPetalFeedURL(url)
    }

    /// The feed category section for grouped display.
    var feedSection: FeedSection {
        if isPodcast { return .audio }
        if isVideoFeed { return .video }
        if isSocialFeed { return .social }
        return .news
    }

    /// Detects Mastodon feeds from unlisted instances by checking for the /@username.rss URL pattern.
    private var hasMastodonFeedURL: Bool {
        guard let urlObj = URL(string: url) else { return false }
        let path = urlObj.path
        return path.hasPrefix("/@") && path.hasSuffix(".rss")
    }
}
