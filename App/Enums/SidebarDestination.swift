import Foundation

enum SidebarDestination: Hashable {
    case today
    case allArticles
    case section(FeedSection)
    case bookmarks
    case topics
    case people
    case list(FeedList)
    case feed(Feed)
    case summaryHeadline(SummaryHeadlineDestination)
    case more
}

extension SidebarDestination {
    /// String token used to persist the sidebar selection across app restarts.
    var persistenceToken: String {
        switch self {
        case .today: "today"
        case .allArticles: "allArticles"
        case .bookmarks: "bookmarks"
        case .topics: "topics"
        case .people: "people"
        case .more: "more"
        case .section(let section): "section:\(section.rawValue)"
        case .list(let list): "list:\(list.id)"
        case .feed(let feed): "feed:\(feed.id)"
        case .summaryHeadline: "today" // Not persisted across launches.
        }
    }

    /// Resolves a previously persisted token. Returns `nil` if the referenced
    /// feed/list/section no longer exists or the token is unrecognized.
    static func resolve(token: String, feedManager: FeedManager) -> SidebarDestination? {
        staticDestination(for: token) ?? parametricDestination(for: token, feedManager: feedManager)
    }

    private static func staticDestination(for token: String) -> SidebarDestination? {
        switch token {
        case "today": .today
        case "allArticles": .allArticles
        case "bookmarks": .bookmarks
        case "topics": .topics
        case "people": .people
        default: nil
        }
    }

    private static func parametricDestination(
        for token: String,
        feedManager: FeedManager
    ) -> SidebarDestination? {
        let parts = token.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let kind = String(parts[0])
        let value = String(parts[1])
        switch kind {
        case "section":
            return FeedSection(rawValue: value).map(SidebarDestination.section)
        case "list":
            guard let id = Int64(value),
                  let list = feedManager.lists.first(where: { $0.id == id }) else { return nil }
            return .list(list)
        case "feed":
            guard let id = Int64(value), let feed = feedManager.feedsByID[id] else { return nil }
            return .feed(feed)
        default:
            return nil
        }
    }
}
