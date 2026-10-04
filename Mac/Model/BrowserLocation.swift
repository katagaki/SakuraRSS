import Foundation
import Hanami

/// What a browser tab shows. Tokens match the iOS browser's so a tab can be
/// handed between devices later.
enum BrowserLocation: Hashable {
    case startPage
    case allContent
    case bookmarks
    case feedSection(FeedSection)
    case feed(Int64)
    case list(Int64)
    case search(String)
    case article(Int64)
}

extension BrowserLocation {

    var persistenceToken: String {
        switch self {
        case .startPage: "startPage"
        case .allContent: "allContent"
        case .bookmarks: "bookmarks"
        case .feedSection(let section): "feedSection:\(section.rawValue)"
        case .feed(let feedID): "feed:\(feedID)"
        case .list(let listID): "list:\(listID)"
        case .search(let query): "search:\(query)"
        case .article(let articleID): "article:\(articleID)"
        }
    }

    init?(persistenceToken token: String) {
        switch token {
        case "startPage": self = .startPage
        case "allContent": self = .allContent
        case "bookmarks": self = .bookmarks
        default:
            let parts = token.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { return nil }
            self.init(kind: String(parts[0]), value: String(parts[1]))
        }
    }

    private init?(kind: String, value: String) {
        switch kind {
        case "feedSection":
            guard let section = FeedSection(rawValue: value) else { return nil }
            self = .feedSection(section)
        case "feed":
            guard let feedID = Int64(value) else { return nil }
            self = .feed(feedID)
        case "list":
            guard let listID = Int64(value) else { return nil }
            self = .list(listID)
        case "search" where !value.isEmpty:
            self = .search(value)
        case "article":
            guard let articleID = Int64(value) else { return nil }
            self = .article(articleID)
        default:
            return nil
        }
    }
}
