import Foundation
import Hanami

extension BrowserLocation {

    /// What Mark All as Read does on this page, or nil where it has no meaning,
    /// such as Today or a single piece of content.
    func markAllReadAction(in feedManager: FeedManager) -> (@MainActor () -> Void)? {
        switch self {
        case .allContent:
            return { feedManager.markAllRead() }
        case .feedSection(let section):
            return { feedManager.markAllRead(for: section) }
        case .feed(let feedID):
            guard let feed = feedManager.feedsByID[feedID] else { return nil }
            return { feedManager.markAllRead(feed: feed) }
        case .list(let listID):
            guard let list = feedManager.lists.first(where: { $0.id == listID }) else { return nil }
            return { feedManager.markAllRead(for: list) }
        case .startPage, .bookmarks, .search, .article, .bookmarkFolder, .bookmarkTag, .topics, .topic, .person,
             .webPage:
            return nil
        }
    }
}
