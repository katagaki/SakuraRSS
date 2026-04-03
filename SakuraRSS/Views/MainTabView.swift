import SwiftUI
import TipKit

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
    @AppStorage("Onboarding.Completed") private var onboardingCompleted: Bool = false
    @AppStorage("Display.UnreadBadgeMode") private var unreadBadgeMode: UnreadBadgeMode = .homeTabOnly
    @Binding var pendingFeedURL: String?
    @Binding var pendingArticleID: Int64?
    @Binding var isInSafeMode: Bool
    @Binding var labsWereDisabled: Bool
    @State private var showingAddFeed = false
    @State private var showingOnboarding = false
    @State private var showingSafeModeAlert = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(String(localized: "Tabs.Home"), systemImage: "text.rectangle.page", value: .home) {
                HomeView(pendingArticleID: $pendingArticleID)
            }
            .badge(unreadBadgeMode == .homeScreenAndHomeTab || unreadBadgeMode == .homeTabOnly
                ? feedManager.totalUnreadCount() : 0)

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
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView {
                onboardingCompleted = true
                ViewStyleSwitcherTip.hasCompletedOnboarding = true
                showingOnboarding = false
            }
            .environment(feedManager)
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
        .onAppear {
            if !onboardingCompleted {
                showingOnboarding = true
            }
            if isInSafeMode && labsWereDisabled {
                showingSafeModeAlert = true
            }
        }
        .alert(String(localized: "SafeMode.Title"), isPresented: $showingSafeModeAlert) {
            Button(String(localized: "SafeMode.OK"), role: .cancel) {
                isInSafeMode = false
                labsWereDisabled = false
            }
        } message: {
            Text("SafeMode.Message")
        }
    }
}
