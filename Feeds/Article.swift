import Foundation

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
