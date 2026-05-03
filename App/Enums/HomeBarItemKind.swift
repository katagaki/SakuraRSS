import Foundation

/// The categories of items that can appear in the home section selection bar.
enum HomeBarItemKind: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case today
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
    case lists
    case topics

    var id: String { rawValue }

    var feedSection: FeedSection? {
        switch self {
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
        case .today, .lists, .topics: nil
        }
    }

    var localizedTitle: String {
        switch self {
        case .today: String(localized: "Home.BarItem.Today", table: "Settings")
        case .lists: String(localized: "Home.BarItem.Lists", table: "Settings")
        case .topics: String(localized: "Home.BarItem.Topics", table: "Settings")
        default: feedSection?.localizedTitle ?? ""
        }
    }

    var systemImage: String {
        switch self {
        case .today: "sun.max"
        case .lists: "list.bullet"
        case .topics: "tag"
        case .feeds: "newspaper"
        case .podcasts: "headphones"
        case .instagram: "photo.on.rectangle"
        case .bluesky, .fediverse, .note, .reddit, .x: "person.2"
        case .substack: "envelope"
        case .vimeo, .youtube, .niconico: "play.rectangle"
        }
    }
}

/// Allowed top-N values for the Topics bar item.
enum HomeBarTopicCount: Int, Codable, CaseIterable, Identifiable, Sendable {
    case top3 = 3
    case top5 = 5
    case top10 = 10

    var id: Int { rawValue }

    var localizedTitle: String {
        String(localized: "Home.Topics.Top \(rawValue)", table: "Settings")
    }
}
