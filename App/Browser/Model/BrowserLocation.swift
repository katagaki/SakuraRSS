import Foundation
import Hanami

/// The root a browser tab is parked on. Stored by identifier rather than by
/// value so a tab survives the underlying feed or list being edited.
enum BrowserLocation: Hashable {
    case startPage
    case feed(Int64)
    case list(Int64)
    case allContent
    case bookmarks
    case search(String)
}

extension BrowserLocation {
    var persistenceToken: String {
        switch self {
        case .startPage: "startPage"
        case .allContent: "allContent"
        case .bookmarks: "bookmarks"
        case .feed(let feedID): "feed:\(feedID)"
        case .list(let listID): "list:\(listID)"
        case .search(let query): "search:\(query)"
        }
    }

    static func resolve(token: String) -> BrowserLocation? {
        switch token {
        case "startPage": return .startPage
        case "allContent": return .allContent
        case "bookmarks": return .bookmarks
        default: break
        }
        let parts = token.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let value = String(parts[1])
        switch String(parts[0]) {
        case "feed": return Int64(value).map(BrowserLocation.feed)
        case "list": return Int64(value).map(BrowserLocation.list)
        case "search": return value.isEmpty ? nil : .search(value)
        default: return nil
        }
    }

    var isStartPage: Bool {
        if case .startPage = self { return true }
        return false
    }
}
