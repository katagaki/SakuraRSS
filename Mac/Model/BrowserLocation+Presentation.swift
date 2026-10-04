import Foundation
import Hanami

extension BrowserLocation {

    func title(in feedManager: FeedManager) -> String {
        switch self {
        case .startPage:
            String(localized: "StartPage.Title", table: "Browser")
        case .allContent:
            String(localized: "Location.AllContent", table: "Browser")
        case .bookmarks:
            String(localized: "Location.Bookmarks", table: "Browser")
        case .feedSection(let section):
            section.localizedTitle
        case .feed(let feedID):
            feedManager.feedsByID[feedID]?.title
                ?? String(localized: "Location.MissingFeed", table: "Browser")
        case .list(let listID):
            feedManager.lists.first { $0.id == listID }?.name
                ?? String(localized: "Location.MissingList", table: "Browser")
        case .search(let query):
            query
        case .article(let articleID):
            feedManager.article(byID: articleID)?.displayTitle ?? ""
        case .bookmarkFolder(let folderID):
            feedManager.bookmarkFolders.first { $0.id == folderID }?.name ?? ""
        case .bookmarkTag(let tagID):
            feedManager.allBookmarkTags().first { $0.id == tagID }?.name ?? ""
        }
    }

    func symbolName(in feedManager: FeedManager) -> String {
        switch self {
        case .startPage: "newspaper"
        case .allContent: "tray.full"
        case .bookmarks: "bookmark"
        case .feedSection(let section): section.symbolName
        case .feed: "dot.radiowaves.up.forward"
        case .list(let listID): feedManager.lists.first { $0.id == listID }?.icon ?? "list.bullet"
        case .search: "magnifyingglass"
        case .article: "doc.text"
        case .bookmarkFolder(let folderID): feedManager.bookmarkFolders.first { $0.id == folderID }?.icon ?? "folder"
        case .bookmarkTag: "tag"
        }
    }
}
