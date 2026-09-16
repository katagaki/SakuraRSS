import SwiftUI
import Hanami

/// Renders whatever a tab is parked on. Every case reuses the view the rest of
/// the app already uses for that destination, so the browser shell stays the
/// only new surface.
struct BrowserRootContentView: View {

    @Environment(FeedManager.self) private var feedManager
    @Namespace private var followingZoom
    let location: BrowserLocation

    var body: some View {
        switch location {
        case .startPage:
            BrowserStartPage()
                .toolbarVisibility(.hidden, for: .navigationBar)
                .browserPage(
                    title: String(localized: "StartPage.Title", table: "Browser"),
                    symbolName: "square.grid.2x2"
                )
        case .allContent:
            HomeSectionView(source: .section(nil))
                .navigationTitle(String(localized: "Location.AllContent", table: "Browser"))
                .toolbarTitleDisplayMode(.inline)
                .browserPage(
                    title: String(localized: "Location.AllContent", table: "Browser"),
                    symbolName: "tray.full"
                )
        case .feeds:
            FollowingPage(followingNavigationNamespace: followingZoom)
                .navigationTitle(String(localized: "Tabs.Feeds"))
                .toolbarTitleDisplayMode(.inline)
                .browserPage(
                    title: String(localized: "Tabs.Feeds"),
                    symbolName: "dot.radiowaves.up.forward"
                )
        case .topics:
            TopicsPageView()
                .browserPage(
                    title: String(localized: "Location.Topics", table: "Browser"),
                    symbolName: "number"
                )
        case .search(let query):
            BrowserSearchResultsView(query: query)
                .browserPage(
                    title: query,
                    subtitle: String(localized: "Location.SearchSubtitle", table: "Browser"),
                    symbolName: "magnifyingglass",
                    searchQuery: query
                )
        case .feed(let feedID):
            feedContent(feedID)
        case .list(let listID):
            listContent(listID)
        }
    }

    @ViewBuilder
    private func feedContent(_ feedID: Int64) -> some View {
        if let feed = feedManager.feedsByID[feedID] {
            FeedArticlesView(feed: feed)
                .browserPage(
                    title: feed.title,
                    subtitle: feed.domain,
                    symbolName: "dot.radiowaves.up.forward",
                    feedID: feed.id
                )
        } else {
            BrowserMissingLocationView(reason: .feed)
                .browserPage(
                    title: String(localized: "Location.MissingFeed", table: "Browser"),
                    symbolName: "questionmark.circle"
                )
        }
    }

    @ViewBuilder
    private func listContent(_ listID: Int64) -> some View {
        if let list = feedManager.lists.first(where: { $0.id == listID }) {
            ListArticlesView(list: list)
                .browserPage(title: list.name, symbolName: list.icon)
        } else {
            BrowserMissingLocationView(reason: .list)
                .browserPage(
                    title: String(localized: "Location.MissingList", table: "Browser"),
                    symbolName: "questionmark.circle"
                )
        }
    }
}
