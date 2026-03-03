import SwiftUI

enum AppTab: String, CaseIterable {
    case home
    case feeds
    case bookmarks
    case search
    case more
}

struct MainTabView: View {

    @Environment(FeedManager.self) var feedManager
    @AppStorage("App.SelectedTab") private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(String(localized: "Tabs.Home"), systemImage: "text.rectangle.page", value: .home) {
                HomeView()
            }
            .badge(feedManager.totalUnreadCount())

            Tab(String(localized: "Tabs.Feeds"), systemImage: "dot.radiowaves.up.forward", value: .feeds) {
                FeedListView()
            }

            Tab(String(localized: "Tabs.Bookmarks"), systemImage: "bookmark", value: .bookmarks) {
                BookmarksView()
            }

            Tab(String(localized: "Tabs.Search"), systemImage: "magnifyingglass", value: .search, role: .search) {
                SearchView()
            }

            Tab(String(localized: "Tabs.More"), systemImage: "ellipsis", value: .more) {
                MoreView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}
