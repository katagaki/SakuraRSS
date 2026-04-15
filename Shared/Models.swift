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
        case .news: String(localized: "FeedSection.News", table: "Feeds")
        case .social: String(localized: "FeedSection.Social", table: "Feeds")
        case .video: String(localized: "FeedSection.Video", table: "Feeds")
        case .audio: String(localized: "FeedSection.Audio", table: "Feeds")
        }
    }
}

nonisolated enum FeedOpenMode: String, CaseIterable, Sendable {
    case inAppViewer
    case inAppBrowser
    case clearThisPage
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

/// User-configurable cooldown between automatic per-feed refreshes.
/// Applied when an automatic trigger (background refresh, app startup,
/// foreground re-enter) asks to refresh every feed.  Does not affect
/// explicit user-triggered refreshes such as pull-to-refresh.
nonisolated enum FeedRefreshCooldown: String, CaseIterable, Sendable {
    case off
    case oneMinute
    case fiveMinutes
    case tenMinutes
    case thirtyMinutes
    case oneHour

    /// Seconds to enforce, or `nil` when cooldown is disabled.
    var seconds: TimeInterval? {
        switch self {
        case .off: return nil
        case .oneMinute: return 60
        case .fiveMinutes: return 5 * 60
        case .tenMinutes: return 10 * 60
        case .thirtyMinutes: return 30 * 60
        case .oneHour: return 60 * 60
        }
    }
}

nonisolated struct FeedList: Identifiable, Hashable, Sendable {
    let id: Int64
    var name: String
    var icon: String
    var displayStyle: String?
    var sortOrder: Int
}

nonisolated enum ListIcon: String, CaseIterable, Identifiable, Sendable {
    // News categories
    case newspaper
    case bookClosed = "book.closed"
    case globe
    case megaphone
    case exclamationmarkTriangle = "exclamationmark.triangle"
    case flame
    case bolt
    case eyeglasses
    case magnifyingglass
    case textQuote = "text.quote"

    // Technology & science
    case laptopcomputer
    case iphone
    case serverRack = "server.rack"
    case cpu
    case wifi
    case antenna = "antenna.radiowaves.left.and.right"
    case atom
    case flask = "flask.fill"
    case stethoscope
    case cross = "cross.case"

    // Sports & fitness
    case sportscourt
    case figureRun = "figure.run"
    case soccerball
    case basketball
    case football = "football.fill"
    case tennisRacket = "tennis.racket"
    case trophy
    case medal = "medal.fill"
    case bicycle
    case dumbbell

    // Entertainment & video
    case film
    case tv
    case playRectangle = "play.rectangle"
    case theatermasks = "theatermasks.fill"
    case popcorn
    case camera
    case videoCamera = "video.fill"
    case rectangleOnRectangle = "rectangle.on.rectangle"
    case sparkles
    case wand = "wand.and.stars"

    // Music & podcasts
    case musicNote = "music.note"
    case musicMic = "music.mic"
    case headphones
    case micFill = "mic.fill"
    case waveform
    case radioFill = "radio.fill"
    case hifispeakerFill = "hifispeaker.fill"
    case pianokeys
    case guitars = "guitars.fill"
    case dial = "dial.medium.fill"

    // Food & lifestyle
    case forkKnife = "fork.knife"
    case cupAndSaucer = "cup.and.saucer.fill"
    case wineglass
    case cart
    case bagFill = "bag.fill"
    case tshirt
    case comb
    case pawprint
    case leaf
    case tree

    // Business & finance
    case briefcase
    case dollarsignCircle = "dollarsign.circle"
    case chartLineUptrend = "chart.line.uptrend.xyaxis"
    case building2 = "building.2"
    case banknote
    case creditcard
    case docText = "doc.text"
    case envelope
    case phone
    case signature

    // Education & culture
    case graduationcap
    case booksVertical = "books.vertical"
    case textBookClosed = "text.book.closed"
    case characterBubble = "character.bubble"
    case globe2 = "globe.americas"
    case buildingColumns = "building.columns"
    case scroll
    case puzzlepiece
    case lightbulb
    case brain

    // Travel & places
    case airplane
    case car
    case bus
    case ferry = "ferry.fill"
    case mappin
    case map
    case mountain = "mountain.2"
    case house
    case tent
    case beach = "beach.umbrella"

    // General
    case heart
    case star
    case paintbrush
    case wrench
    case gamecontroller
    case photo
    case handThumbsup = "hand.thumbsup"
    case faceSmilingFill = "face.smiling.fill"
    case personFill = "person.fill"
    case person2Fill = "person.2.fill"

    var id: String { rawValue }
}

nonisolated enum FeedDisplayStyle: String, CaseIterable, Sendable {
    case inbox
    case feed
    case feedCompact
    case magazine
    case compact
    case video
    case photos
    case podcast
    case timeline
    case cards
    case grid
    case scroll

    var localizedName: String {
        switch self {
        case .inbox: String(localized: "Style.Inbox", table: "Articles")
        case .feed: String(localized: "Style.Feed", table: "Articles")
        case .feedCompact: String(localized: "Style.FeedCompact", table: "Articles")
        case .magazine: String(localized: "Style.Magazine", table: "Articles")
        case .compact: String(localized: "Style.Compact", table: "Articles")
        case .video: String(localized: "Style.Video", table: "Articles")
        case .photos: String(localized: "Style.Photos", table: "Articles")
        case .podcast: String(localized: "Style.Podcast", table: "Articles")
        case .timeline: String(localized: "Style.Timeline", table: "Articles")
        case .cards: String(localized: "Style.Cards", table: "Articles")
        case .grid: String(localized: "Style.Grid", table: "Articles")
        case .scroll: String(localized: "Style.Scroll", table: "Articles")
        }
    }

    var requiresImages: Bool {
        switch self {
        case .magazine, .photos, .cards, .grid: true
        default: false
        }
    }
}

nonisolated struct TranscriptSegment: Codable, Identifiable, Sendable, Hashable {
    let id: Int
    let start: TimeInterval
    let end: TimeInterval
    let text: String
}
