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
    case bookmarkFolder(Int64)
    case bookmarkTag(Int64)
    case topics
    case topic(String)
    case person(String)
    /// A page that isn't content Sakura has saved, as `sakura://open` and
    /// links inside content open, shown the way `mode` asks.
    case webPage(url: String, mode: OpenArticleRequest.Mode, textMode: OpenArticleRequest.TextMode = .auto)
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
        case .bookmarkFolder(let folderID): "bookmarkFolder:\(folderID)"
        case .bookmarkTag(let tagID): "bookmarkTag:\(tagID)"
        case .topics: "topics"
        case .topic(let name): "topic:\(name)"
        case .person(let name): "person:\(name)"
        case .webPage(let url, let mode, let textMode): "webPage:\(mode.rawValue),\(textMode.rawValue)|\(url)"
        }
    }

    init?(persistenceToken token: String) {
        switch token {
        case "startPage": self = .startPage
        case "allContent": self = .allContent
        case "bookmarks": self = .bookmarks
        case "topics": self = .topics
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
        case "webPage":
            let parts = value.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
            let modes = parts.first?.split(separator: ",").map(String.init) ?? []
            guard parts.count == 2, !parts[1].isEmpty,
                  let mode = modes.first.flatMap(OpenArticleRequest.Mode.init(rawValue:)) else { return nil }
            let textMode = modes.dropFirst().first.flatMap(OpenArticleRequest.TextMode.init(rawValue:)) ?? .auto
            self = .webPage(url: String(parts[1]), mode: mode, textMode: textMode)
        case "search", "topic", "person":
            guard !value.isEmpty else { return nil }
            self = kind == "search" ? .search(value) : kind == "topic" ? .topic(value) : .person(value)
        default:
            guard let identifier = Int64(value), let make = Self.identifiedKinds[kind] else { return nil }
            self = make(identifier)
        }
    }

    private static let identifiedKinds: [String: (Int64) -> BrowserLocation] = [
        "feed": BrowserLocation.feed,
        "list": BrowserLocation.list,
        "article": BrowserLocation.article,
        "bookmarkFolder": BrowserLocation.bookmarkFolder,
        "bookmarkTag": BrowserLocation.bookmarkTag
    ]
}
