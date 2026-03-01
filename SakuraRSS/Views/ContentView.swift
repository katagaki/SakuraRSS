import SwiftUI

struct ContentView: View {

    @Environment(FeedManager.self) var feedManager

    var body: some View {
        TabView {
            Tab(String(localized: "Tabs.Feeds"), systemImage: "dot.radiowaves.up.forward") {
                FeedListView()
            }
            .badge(feedManager.totalUnreadCount())

            Tab(String(localized: "Tabs.Bookmarks"), systemImage: "bookmark") {
                BookmarksView()
            }

            Tab(String(localized: "Tabs.More"), systemImage: "ellipsis") {
                MoreView()
            }
        }
    }
}
