import Foundation

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
