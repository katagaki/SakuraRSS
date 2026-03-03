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

    var domain: String {
        URL(string: siteURL)?.host ?? URL(string: url)?.host ?? ""
    }

    var isVideoFeed: Bool {
        VideoDomains.shouldPreferVideo(feedDomain: domain)
    }

    var isFeedViewDomain: Bool {
        FeedViewDomains.shouldPreferFeedView(feedDomain: domain)
    }
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
}

nonisolated enum FeedDisplayStyle: String, CaseIterable, Sendable {
    case inbox
    case feed
    case magazine
    case compact
    case video
    case photos
    case podcast
}
