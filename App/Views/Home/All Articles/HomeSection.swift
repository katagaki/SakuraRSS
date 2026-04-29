import SwiftUI

enum HomeSection: String, CaseIterable, Identifiable {
    case all
    case feeds
    case podcasts
    case bluesky
    case instagram
    case mastodon
    case note
    case pixelfed
    case reddit
    case substack
    case vimeo
    case x // swiftlint:disable:this identifier_name
    case youtube
    case niconico

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .all: String(localized: "Shared.AllArticles")
        case .feeds: String(localized: "FeedSection.Feeds", table: "Feeds")
        case .podcasts: String(localized: "FeedSection.Podcasts", table: "Feeds")
        case .bluesky: String(localized: "FeedSection.Bluesky", table: "Feeds")
        case .instagram: String(localized: "FeedSection.Instagram", table: "Feeds")
        case .mastodon: String(localized: "FeedSection.Mastodon", table: "Feeds")
        case .note: String(localized: "FeedSection.Note", table: "Feeds")
        case .pixelfed: String(localized: "FeedSection.Pixelfed", table: "Feeds")
        case .reddit: String(localized: "FeedSection.Reddit", table: "Feeds")
        case .substack: String(localized: "FeedSection.Substack", table: "Feeds")
        case .vimeo: String(localized: "FeedSection.Vimeo", table: "Feeds")
        case .x: String(localized: "FeedSection.X", table: "Feeds")
        case .youtube: String(localized: "FeedSection.YouTube", table: "Feeds")
        case .niconico: String(localized: "FeedSection.Niconico", table: "Feeds")
        }
    }

    var systemImage: String? {
        switch self {
        case .all: "square.stack"
        case .feeds: "newspaper"
        case .podcasts: "headphones"
        default: nil
        }
    }

    var feedSection: FeedSection? {
        switch self {
        case .all: nil
        case .feeds: .feeds
        case .podcasts: .podcasts
        case .bluesky: .bluesky
        case .instagram: .instagram
        case .mastodon: .mastodon
        case .note: .note
        case .pixelfed: .pixelfed
        case .reddit: .reddit
        case .substack: .substack
        case .vimeo: .vimeo
        case .x: .x
        case .youtube: .youtube
        case .niconico: .niconico
        }
    }
}
