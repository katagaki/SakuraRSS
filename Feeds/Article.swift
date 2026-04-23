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
    /// All image URLs for Instagram carousel posts.
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

    var isXPostURL: Bool {
        guard let parsed = URL(string: url) else { return false }
        return XProfileScraper.isXPostURL(parsed)
    }

    var isInstagramPostURL: Bool {
        guard let parsed = URL(string: url) else { return false }
        return InstagramProfileScraper.isInstagramPostURL(parsed)
    }

    var isPodcastEpisode: Bool {
        audioURL != nil
    }

    /// Filters out placeholder summaries (e.g. "Comments" from Hacker News).
    var hasMeaningfulSummary: Bool {
        guard let summary else { return false }
        return summary.count >= 20
    }
}
