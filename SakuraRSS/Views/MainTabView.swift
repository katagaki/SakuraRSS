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
    @Binding var pendingFeedURL: String?
    @Binding var pendingArticleID: Int64?
    @State private var showingAddFeed = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(String(localized: "Tabs.Home"), systemImage: "text.rectangle.page", value: .home) {
                HomeView(pendingArticleID: $pendingArticleID)
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
        .sheet(isPresented: $showingAddFeed) {
            AddFeedView(initialURL: pendingFeedURL ?? "")
                .environment(feedManager)
                .onDisappear {
                    pendingFeedURL = nil
                }
        }
        .onChange(of: pendingFeedURL) {
            if pendingFeedURL != nil {
                showingAddFeed = true
            }
        }
        .onChange(of: pendingArticleID) {
            if pendingArticleID != nil {
                selectedTab = .home
            }
        }
    }
}
