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

    var domain: String {
        URL(string: siteURL)?.host ?? URL(string: url)?.host ?? ""
    }

    var isVideoFeed: Bool {
        VideoDomains.shouldPreferVideo(feedDomain: domain)
    }

    var isXFeed: Bool {
        XProfileScraper.isXFeedURL(url)
    }

    var isInstagramFeed: Bool {
        InstagramProfileScraper.isInstagramFeedURL(url)
    }

    var isFeedViewDomain: Bool {
        isXFeed || isInstagramFeed
            || FeedViewDomains.shouldPreferFeedView(feedDomain: domain) || hasMastodonFeedURL
    }

    var isTimelineViewDomain: Bool {
        TimelineViewDomains.shouldPreferTimeline(feedDomain: domain)
    }

    var isRedditFeed: Bool {
        let host = domain.lowercased()
        return host == "reddit.com" || host.hasSuffix(".reddit.com")
    }

    var isPhotoViewDomain: Bool {
        PhotoViewDomains.shouldPreferPhotoView(feedDomain: domain)
    }

    var isSocialFeed: Bool {
        isXFeed || isInstagramFeed || isRedditFeed || isFeedViewDomain || isPhotoViewDomain
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

nonisolated enum FeedSection: String, CaseIterable, Sendable {
    case news
    case social
    case video
    case audio

    var localizedTitle: String {
        switch self {
        case .news: String(localized: "FeedSection.News")
        case .social: String(localized: "FeedSection.Social")
        case .video: String(localized: "FeedSection.Video")
        case .audio: String(localized: "FeedSection.Audio")
        }
    }
}

nonisolated enum FeedOpenMode: String, CaseIterable, Sendable {
    case inAppViewer
    case inAppBrowser
    case browser
}

nonisolated struct Article: Identifiable, Hashable, Sendable {
    let id: Int64
    let feedID: Int64
    var title: String
    var url: String
    var author: String?
    var summary: String?
    var content: String?
    var imageURL: String?
    /// All image URLs for Instagram carousel posts. Empty for single-image posts.
    var carouselImageURLs: [String] = []
    var publishedDate: Date?
    var isRead: Bool
    var isBookmarked: Bool
    var audioURL: String?
    var duration: Int?

    var isYouTubeURL: Bool {
        let lowered = url.lowercased()
        return lowered.contains("youtube.com") || lowered.contains("youtu.be")
    }

    /// Whether the article URL points to a specific X/Twitter post (status).
    var isXPostURL: Bool {
        guard let parsed = URL(string: url) else { return false }
        return XProfileScraper.isXPostURL(parsed)
    }

    /// Whether the article URL points to a specific Instagram post.
    var isInstagramPostURL: Bool {
        guard let parsed = URL(string: url) else { return false }
        return InstagramProfileScraper.isInstagramPostURL(parsed)
    }

    var isPodcastEpisode: Bool {
        audioURL != nil
    }

    /// Whether the summary has enough meaningful content to display.
    /// Filters out placeholder text like "Comments" from Hacker News feeds.
    var hasMeaningfulSummary: Bool {
        guard let summary else { return false }
        return summary.count >= 20
    }
}

nonisolated enum YouTubeOpenMode: String, CaseIterable, Sendable {
    case inAppPlayer
    case youTubeApp
    case browser
}

nonisolated enum ArticleSource: String, CaseIterable, Sendable {
    case automatic
    case fetchText
    case extractText
    case feedText
}

nonisolated enum MarkAllReadPosition: String, CaseIterable, Sendable {
    case bottom
    case top
    case none
}

nonisolated enum UnreadBadgeMode: String, CaseIterable, Sendable {
    case homeScreenAndHomeTab
    case homeScreenOnly
    case homeTabOnly
    case none
}

nonisolated struct FeedList: Identifiable, Hashable, Sendable {
    let id: Int64
    var name: String
    var icon: String
    var displayStyle: String?
    var sortOrder: Int
}

nonisolated enum ListIcon: String, CaseIterable, Identifiable, Sendable {
    case newspaper
    case bookClosed = "book.closed"
    case laptopcomputer
    case globe
    case sportscourt
    case gamecontroller
    case film
    case musicNote = "music.note"
    case forkKnife = "fork.knife"
    case cart
    case briefcase
    case graduationcap
    case heart
    case star
    case leaf
    case airplane
    case house
    case paintbrush
    case wrench
    case dollarsignCircle = "dollarsign.circle"

    var id: String { rawValue }
}

nonisolated enum FeedDisplayStyle: String, CaseIterable, Sendable {
    case inbox
    case feed
    case magazine
    case compact
    case video
    case photos
    case podcast
    case timeline
    case cards
    case grid

    var requiresImages: Bool {
        switch self {
        case .magazine, .photos, .cards, .grid: true
        default: false
        }
    }
}
