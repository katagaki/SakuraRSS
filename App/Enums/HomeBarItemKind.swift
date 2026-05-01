import Foundation

/// The categories of items that can appear in the home section selection bar.
enum HomeBarItemKind: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case following
    case feedSections
    case lists
    case topics

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .following: String(localized: "Home.BarItem.Following", table: "Settings")
        case .feedSections: String(localized: "Home.BarItem.FeedSections", table: "Settings")
        case .lists: String(localized: "Home.BarItem.Lists", table: "Settings")
        case .topics: String(localized: "Home.BarItem.Topics", table: "Settings")
        }
    }

    var systemImage: String {
        switch self {
        case .following: "square.stack"
        case .feedSections: "rectangle.stack"
        case .lists: "list.bullet.rectangle"
        case .topics: "tag"
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
