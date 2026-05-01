import Foundation

/// The categories of items that can appear in the home section selection bar.
enum HomeBarItemKind: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
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
    case lists
    case topics

    var id: String { rawValue }

    var feedSection: FeedSection? {
        switch self {
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
        case .lists, .topics: nil
        }
    }

    var localizedTitle: String {
        switch self {
        case .lists: String(localized: "Home.BarItem.Lists", table: "Settings")
        case .topics: String(localized: "Home.BarItem.Topics", table: "Settings")
        default: feedSection?.localizedTitle ?? ""
        }
    }

    var systemImage: String {
        switch self {
        case .lists: "list.bullet"
        case .topics: "tag"
        case .feeds: "newspaper"
        case .podcasts: "headphones"
        case .instagram, .pixelfed: "photo.on.rectangle"
        case .bluesky, .mastodon, .note, .reddit, .x: "person.2"
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
