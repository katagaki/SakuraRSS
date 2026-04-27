import Foundation

nonisolated enum FeedSection: String, CaseIterable, Sendable {
    case feeds
    case podcasts
    case bluesky
    case instagram
    case mastodon
    case note
    case pixelfed
    case reddit
    case vimeo
    case x // swiftlint:disable:this identifier_name
    case youtube
    case niconico

    var localizedTitle: String {
        switch self {
        case .feeds: String(localized: "FeedSection.Feeds", table: "Feeds")
        case .podcasts: String(localized: "FeedSection.Podcasts", table: "Feeds")
        case .bluesky: String(localized: "FeedSection.Bluesky", table: "Feeds")
        case .instagram: String(localized: "FeedSection.Instagram", table: "Feeds")
        case .mastodon: String(localized: "FeedSection.Mastodon", table: "Feeds")
        case .note: String(localized: "FeedSection.Note", table: "Feeds")
        case .pixelfed: String(localized: "FeedSection.Pixelfed", table: "Feeds")
        case .reddit: String(localized: "FeedSection.Reddit", table: "Feeds")
        case .vimeo: String(localized: "FeedSection.Vimeo", table: "Feeds")
        case .x: String(localized: "FeedSection.X", table: "Feeds")
        case .youtube: String(localized: "FeedSection.YouTube", table: "Feeds")
        case .niconico: String(localized: "FeedSection.Niconico", table: "Feeds")
        }
    }
}
