import Foundation
import Hanami

extension BrowserLocation {

    func title(in feedManager: FeedManager) -> String {
        if let fixedTitle {
            return fixedTitle
        }
        switch self {
        case .feedSection(let section):
            return section.localizedTitle
        case .feed(let feedID):
            return feedManager.feedsByID[feedID]?.title
                ?? String(localized: "Location.MissingFeed", table: "Browser")
        case .list(let listID):
            return feedManager.lists.first { $0.id == listID }?.name
                ?? String(localized: "Location.MissingList", table: "Browser")
        case .article(let articleID):
            return feedManager.article(byID: articleID)?.displayTitle ?? ""
        case .bookmarkFolder(let folderID):
            return feedManager.bookmarkFolders.first { $0.id == folderID }?.name ?? ""
        case .bookmarkTag(let tagID):
            return feedManager.allBookmarkTags().first { $0.id == tagID }?.name ?? ""
        case .search(let name), .topic(let name), .person(let name):
            return name
        case .webPage(let url, _, _):
            return URL(string: url)?.host() ?? url
        default:
            return ""
        }
    }

    /// Pages whose title doesn't depend on any data.
    private var fixedTitle: String? {
        switch self {
        case .startPage: String(localized: "StartPage.Title", table: "Browser")
        case .allContent: String(localized: "Location.AllContent", table: "Browser")
        case .bookmarks: String(localized: "Location.Bookmarks", table: "Browser")
        case .topics: String(localized: "Location.Topics", table: "Browser")
        default: nil
        }
    }

    func symbolName(in feedManager: FeedManager) -> String {
        switch self {
        case .feedSection(let section):
            section.symbolName
        case .list(let listID):
            feedManager.lists.first { $0.id == listID }?.icon ?? "list.bullet"
        case .bookmarkFolder(let folderID):
            feedManager.bookmarkFolders.first { $0.id == folderID }?.icon ?? "folder"
        default:
            fixedSymbolName
        }
    }

    private var fixedSymbolName: String {
        switch self {
        case .startPage: "newspaper"
        case .allContent: "tray.full"
        case .bookmarks: "bookmark"
        case .feed: "dot.radiowaves.up.forward"
        case .search: "magnifyingglass"
        case .article: "doc.text"
        case .bookmarkTag: "tag"
        case .person: "person"
        case .webPage: "globe"
        default: "number"
        }
    }
}
