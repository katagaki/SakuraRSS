import EnhancedNavigation
import Foundation
import Hanami

/// The root a browser tab is parked on. Stored by identifier rather than by
/// value so a tab survives the underlying feed or list being edited.
enum BrowserLocation: Hashable {
    case startPage
    case feed(Int64)
    case list(Int64)
    case allContent
    case feeds
    case feedSection(FeedSection)
    case topics
    case search(String)
}

extension BrowserLocation: @MainActor TabRoot {
    static var newTabRoot: BrowserLocation { .startPage }

    init?(persistenceToken: String) {
        guard let location = BrowserLocation.resolve(token: persistenceToken) else { return nil }
        self = location
    }

    var isRecordedAsVisit: Bool {
        if case .feed = self { return true }
        return false
    }

    var persistenceToken: String {
        switch self {
        case .startPage: "startPage"
        case .allContent: "allContent"
        case .feeds: "feeds"
        case .feedSection(let section): "feedSection:\(section.rawValue)"
        case .topics: "topics"
        case .feed(let feedID): "feed:\(feedID)"
        case .list(let listID): "list:\(listID)"
        case .search(let query): "search:\(query)"
        }
    }

    static func resolve(token: String) -> BrowserLocation? {
        switch token {
        case "startPage": return .startPage
        case "allContent": return .allContent
        case "feeds": return .feeds
        case "topics": return .topics
        default: break
        }
        let parts = token.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        return resolve(kind: String(parts[0]), value: String(parts[1]))
    }

    private static func resolve(kind: String, value: String) -> BrowserLocation? {
        switch kind {
        case "feed": return Int64(value).map(BrowserLocation.feed)
        case "list": return Int64(value).map(BrowserLocation.list)
        case "feedSection": return FeedSection(rawValue: value).map(BrowserLocation.feedSection)
        case "search": return value.isEmpty ? nil : .search(value)
        default: return nil
        }
    }
}
