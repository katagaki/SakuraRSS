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
            symbolic(
                title: String(localized: "StartPage.Title", table: "Browser"),
                symbolName: "square.grid.2x2"
            )
        case .allContent:
            symbolic(
                title: String(localized: "Location.AllContent", table: "Browser"),
                symbolName: "tray.full"
            )
        case .feeds:
            BrowserLocationDescription(
                title: String(localized: "Tabs.Feeds"),
                subtitle: nil,
                symbolName: "dot.radiowaves.up.forward",
                feed: nil
            )
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

    /// Takes a resolved title rather than a key: string extraction cannot see
    /// through a variable, so a key passed in here lands in the default table
    /// untranslated.
    private static func symbolic(title: String, symbolName: String) -> BrowserLocationDescription {
        BrowserLocationDescription(
            title: title,
            subtitle: nil,
            symbolName: symbolName,
            feed: nil
        )
    }

    @MainActor
    private static func describeFeed(_ feedID: Int64, feedManager: FeedManager) -> BrowserLocationDescription {
        guard let feed = feedManager.feedsByID[feedID] else {
            return symbolic(
                title: String(localized: "Location.MissingFeed", table: "Browser"),
                symbolName: "questionmark.circle"
            )
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
            return symbolic(
                title: String(localized: "Location.MissingList", table: "Browser"),
                symbolName: "questionmark.circle"
            )
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
