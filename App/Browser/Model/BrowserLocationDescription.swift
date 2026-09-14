import Foundation
import Hanami

/// Everything the address bar and tab cards need to label a location, resolved
/// once against the current feed list.
struct BrowserLocationDescription {
    let title: String
    let subtitle: String?
    let symbolName: String
    let feed: Feed?

    @MainActor
    static func describe(_ location: BrowserLocation, feedManager: FeedManager) -> BrowserLocationDescription {
        switch location {
        case .startPage:
            symbolic(key: "StartPage.Title", symbolName: "square.grid.2x2")
        case .allContent:
            symbolic(key: "Location.AllContent", symbolName: "tray.full")
        case .search(let query):
            BrowserLocationDescription(
                title: query,
                subtitle: String(localized: "Location.SearchSubtitle", table: "Browser"),
                symbolName: "magnifyingglass",
                feed: nil
            )
        case .feed(let feedID):
            describeFeed(feedID, feedManager: feedManager)
        case .list(let listID):
            describeList(listID, feedManager: feedManager)
        }
    }

    private static func symbolic(key: String.LocalizationValue, symbolName: String) -> BrowserLocationDescription {
        BrowserLocationDescription(
            title: String(localized: key, table: "Browser"),
            subtitle: nil,
            symbolName: symbolName,
            feed: nil
        )
    }

    @MainActor
    private static func describeFeed(_ feedID: Int64, feedManager: FeedManager) -> BrowserLocationDescription {
        guard let feed = feedManager.feedsByID[feedID] else {
            return symbolic(key: "Location.MissingFeed", symbolName: "questionmark.circle")
        }
        return BrowserLocationDescription(
            title: feed.title,
            subtitle: feed.domain,
            symbolName: "dot.radiowaves.up.forward",
            feed: feed
        )
    }

    @MainActor
    private static func describeList(_ listID: Int64, feedManager: FeedManager) -> BrowserLocationDescription {
        guard let list = feedManager.lists.first(where: { $0.id == listID }) else {
            return symbolic(key: "Location.MissingList", symbolName: "questionmark.circle")
        }
        return BrowserLocationDescription(
            title: list.name,
            subtitle: nil,
            symbolName: list.icon,
            feed: nil
        )
    }

    /// The label for a tab. A live tab reports its own title, which is how the
    /// address bar follows pushes the shell never sees.
    @MainActor
    static func describe(_ tab: BrowserTab, feedManager: FeedManager) -> BrowserLocationDescription {
        guard let identity = tab.pageIdentity else {
            return describe(tab.location, feedManager: feedManager)
        }
        return BrowserLocationDescription(
            title: identity.title,
            subtitle: identity.subtitle,
            symbolName: identity.symbolName,
            feed: identity.feedID.flatMap { feedManager.feedsByID[$0] }
        )
    }
}
