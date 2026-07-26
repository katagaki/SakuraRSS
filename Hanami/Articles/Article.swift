import Foundation

public nonisolated struct Article: Identifiable, Hashable, Sendable {
    public let id: Int64
    public let feedID: Int64
    public var title: String
    public var url: String
    public var author: String?
    public var summary: String?
    public var content: String?
    public var imageURL: String?
    /// All image URLs for Instagram carousel posts.
    public var carouselImageURLs: [String] = []
    public var publishedDate: Date?
    public var isRead: Bool
    public var isBookmarked: Bool
    public var audioURL: String?
    public var duration: Int?
    /// Saved into Bookmarks from another app via the share extension rather
    /// than originating from a subscribed feed.
    public var isExternalBookmark: Bool = false

    public init(
        id: Int64,
        feedID: Int64,
        title: String,
        url: String,
        author: String? = nil,
        summary: String? = nil,
        content: String? = nil,
        imageURL: String? = nil,
        carouselImageURLs: [String] = [],
        publishedDate: Date? = nil,
        isRead: Bool = false,
        isBookmarked: Bool = false,
        audioURL: String? = nil,
        duration: Int? = nil,
        isExternalBookmark: Bool = false
    ) {
        self.id = id
        self.feedID = feedID
        self.title = title
        self.url = url
        self.author = author
        self.summary = summary
        self.content = content
        self.imageURL = imageURL
        self.carouselImageURLs = carouselImageURLs
        self.publishedDate = publishedDate
        self.isRead = isRead
        self.isBookmarked = isBookmarked
        self.audioURL = audioURL
        self.duration = duration
        self.isExternalBookmark = isExternalBookmark
    }

    public var hasLink: Bool {
        !url.isEmpty && URL(string: url) != nil
    }

    public var isYouTubeURL: Bool {
        let lowered = url.lowercased()
        return lowered.contains("youtube.com") || lowered.contains("youtu.be")
    }

    public var isXPostURL: Bool {
        guard let parsed = URL(string: url) else { return false }
        return XProvider.isXPostURL(parsed)
    }

    public var isInstagramPostURL: Bool {
        guard let parsed = URL(string: url) else { return false }
        return InstagramProvider.isInstagramPostURL(parsed)
    }

    public var isBlueskyPostURL: Bool {
        guard let parsed = URL(string: url) else { return false }
        return BlueskyProvider.isBlueskyPostURL(parsed)
    }

    public var isPodcastEpisode: Bool {
        audioURL != nil
    }

    /// X serves video post thumbnails from dedicated paths, so the image URL
    /// alone identifies posts with playable video. GIF posts
    /// (`tweet_video_thumb`) are excluded because they autoplay.
    public var hasXVideoThumbnail: Bool {
        guard let imageURL else { return false }
        return imageURL.contains("ext_tw_video_thumb")
            || imageURL.contains("amplify_video_thumb")
    }

    /// Filters out placeholder summaries (e.g. "Comments" from Hacker News).
    public var hasMeaningfulSummary: Bool {
        guard let summary else { return false }
        return summary.count >= 20
    }
}
