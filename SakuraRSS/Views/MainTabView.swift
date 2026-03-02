import SwiftUI

struct MainTabView: View {

    @Environment(FeedManager.self) var feedManager

    var body: some View {
        TabView {
            Tab(String(localized: "Tabs.Home"), systemImage: "text.rectangle.page") {
                HomeView()
            }
            .badge(feedManager.totalUnreadCount())

            Tab(String(localized: "Tabs.Feeds"), systemImage: "dot.radiowaves.up.forward") {
                FeedListView()
            }

            Tab(String(localized: "Tabs.Bookmarks"), systemImage: "bookmark") {
                BookmarksView()
            }

            Tab(String(localized: "Tabs.Search"), systemImage: "magnifyingglass", role: .search) {
                SearchView()
            }

            Tab(String(localized: "Tabs.More"), systemImage: "ellipsis") {
                MoreView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}
