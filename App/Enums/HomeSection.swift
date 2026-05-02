import SwiftUI

enum HomeSection: String, CaseIterable, Identifiable {
    case all
    case feeds
    case podcasts
    case bluesky
    case fediverse
    case instagram
    case note
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
        case .fediverse: String(localized: "FeedSection.Fediverse", table: "Feeds")
        case .instagram: String(localized: "FeedSection.Instagram", table: "Feeds")
        case .note: String(localized: "FeedSection.Note", table: "Feeds")
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

    /// Brand-tinted accent used for the Today top tab bar's selected indicator.
    var tabAccentColor: Color {
        switch self {
        case .podcasts: .indigo
        case .instagram: .brown
        case .note: .gray
        case .reddit, .substack: .orange
        case .x: .blue
        case .youtube: .red
        default: .accentColor
        }
    }

    var feedSection: FeedSection? {
        switch self {
        case .all: nil
        case .feeds: .feeds
        case .podcasts: .podcasts
        case .bluesky: .bluesky
        case .fediverse: .fediverse
        case .instagram: .instagram
        case .note: .note
        case .reddit: .reddit
        case .substack: .substack
        case .vimeo: .vimeo
        case .x: .x
        case .youtube: .youtube
        case .niconico: .niconico
        }
    }
}
