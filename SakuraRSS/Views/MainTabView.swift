import SwiftUI
import TipKit

enum AppTab: String, CaseIterable {
    case home
    case feeds
    case lists
    case bookmarks
    case search
}

struct MainTabView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("App.SelectedTab") private var selectedTab: AppTab = .home
    @AppStorage("Onboarding.Completed") private var onboardingCompleted: Bool = false
    @AppStorage("Display.UnreadBadgeMode") private var unreadBadgeMode: UnreadBadgeMode = .none
    @Binding var pendingFeedURL: String?
    @Binding var pendingArticleID: Int64?
    @State private var showingAddFeed = false
    @State private var showingOnboarding = false
    @State private var miniPlayerPresentedArticle: Article?
    @Namespace private var miniPlayerTransition

    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            IPadSidebarView(
                pendingFeedURL: $pendingFeedURL,
                pendingArticleID: $pendingArticleID
            )
        } else {
            iPhoneTabView
        }
    }

    private var iPhoneTabView: some View {
        TabView(selection: $selectedTab) {
            Tab("Tabs.Home", systemImage: "text.rectangle.page", value: .home) {
                HomeView(pendingArticleID: $pendingArticleID)
            }
            .badge(unreadBadgeMode == .homeScreenAndHomeTab || unreadBadgeMode == .homeTabOnly
                ? feedManager.totalUnreadCount() : 0)

            Tab("Tabs.Feeds", systemImage: "dot.radiowaves.up.forward", value: .feeds) {
                FeedListView()
            }

            Tab("Tabs.Lists", systemImage: "square.fill.text.grid.1x2", value: .lists) {
                ListsView()
            }

            Tab("Tabs.Bookmarks", systemImage: "bookmark", value: .bookmarks) {
                BookmarksView()
            }

            Tab("Tabs.Discover", systemImage: "magnifyingglass", value: .search, role: .search) {
                SearchView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            MiniPlayerView { article in
                miniPlayerPresentedArticle = article
            }
            .matchedTransitionSource(id: "miniPlayer", in: miniPlayerTransition)
        }
        .sheet(item: $miniPlayerPresentedArticle) { article in
            NavigationStack {
                PodcastEpisodeView(article: article)
                    .environment(feedManager)
            }
            .navigationTransition(.zoom(sourceID: "miniPlayer", in: miniPlayerTransition))
        }
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
        }
    }
}
