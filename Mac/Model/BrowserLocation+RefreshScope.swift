import Foundation
import Hanami

/// The feeds a page refreshes and the scope its progress is filed under,
/// keyed the same way iOS keys its pages so both report alike.
struct RefreshScope {
    let key: String
    let feeds: [Feed]
}

extension BrowserLocation {

    func refreshScope(in feedManager: FeedManager) -> RefreshScope {
        switch self {
        case .startPage:
            RefreshScope(key: "section.today", feeds: feedManager.feeds)
        case .feedSection(let section):
            RefreshScope(
                key: "section.\(section.rawValue)",
                feeds: feedManager.feeds.filter { $0.feedSection == section }
            )
        case .feed(let feedID):
            RefreshScope(key: "feed.\(feedID)", feeds: feedManager.feedsByID[feedID].map { [$0] } ?? [])
        case .list(let listID):
            RefreshScope(
                key: "list.\(listID)",
                feeds: feedManager.lists.first { $0.id == listID }.map(feedManager.feeds(for:)) ?? []
            )
        case .allContent, .bookmarks, .search, .article, .bookmarkFolder, .bookmarkTag, .topics, .topic, .person,
             .webPage:
            RefreshScope(key: "section.all", feeds: feedManager.feeds)
        }
    }
}
