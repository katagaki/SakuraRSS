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

    var isFeedViewDomain: Bool {
        FeedViewDomains.shouldPreferFeedView(feedDomain: domain) || hasMastodonFeedURL
    }

    var isTimelineViewDomain: Bool {
        TimelineViewDomains.shouldPreferTimeline(feedDomain: domain)
    }

    /// Detects Mastodon feeds from unlisted instances by checking for the /@username.rss URL pattern.
    private var hasMastodonFeedURL: Bool {
        guard let urlObj = URL(string: url) else { return false }
        let path = urlObj.path
        return path.hasPrefix("/@") && path.hasSuffix(".rss")
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
    var publishedDate: Date?
    var isRead: Bool
    var isBookmarked: Bool
    var audioURL: String?
    var duration: Int?

    var isYouTubeURL: Bool {
        let lowered = url.lowercased()
        return lowered.contains("youtube.com") || lowered.contains("youtu.be")
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
}
