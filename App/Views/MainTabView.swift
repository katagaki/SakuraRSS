import SwiftUI
import TipKit

enum AppTab: String, CaseIterable {
    case home
    case feeds
    case bookmarks
    case profile
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
    @Binding var pendingOpenRequest: OpenArticleRequest?
    @State private var showingAddFeed = false
    @State private var showingOnboarding = false
    @State private var miniPlayerPresentedArticle: Article?
    @Namespace private var miniPlayerTransition
    private let audioPlayer = AudioPlayer.shared

    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            IPadSidebarView(
                pendingFeedURL: $pendingFeedURL,
                pendingArticleID: $pendingArticleID,
                pendingOpenRequest: $pendingOpenRequest
            )
        } else {
            iPhoneTabView
        }
    }

    private var tabView: some View {
        TabView(selection: $selectedTab) {
            Tab("Tabs.Home", systemImage: "newspaper", value: .home) {
                HomeView(
                    pendingArticleID: $pendingArticleID,
                    pendingOpenRequest: $pendingOpenRequest
                )
            }
            .badge(unreadBadgeMode == .homeScreenAndHomeTab || unreadBadgeMode == .homeTabOnly
                ? feedManager.totalUnreadCount() : 0)

            Tab("Tabs.Feeds", systemImage: "dot.radiowaves.up.forward", value: .feeds) {
                FeedListView()
            }

            Tab("Tabs.Bookmarks", systemImage: "bookmark", value: .bookmarks) {
                BookmarksView()
            }

            Tab("Tabs.Profile", systemImage: "person.crop.circle", value: .profile) {
                MoreView(showsCloseButton: false)
            }

            Tab("Tabs.Discover", systemImage: "magnifyingglass", value: .search, role: .search) {
                SearchView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }

    private var iPhoneTabView: some View {
        tabView
            .modifier(MiniPlayerAccessoryModifier(
                audioPlayer: audioPlayer,
                miniPlayerPresentedArticle: $miniPlayerPresentedArticle,
                miniPlayerTransition: miniPlayerTransition
            ))
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
            .onChange(of: pendingOpenRequest) {
                if pendingOpenRequest != nil {
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

private struct MiniPlayerAccessoryModifier: ViewModifier {

    let audioPlayer: AudioPlayer
    @Binding var miniPlayerPresentedArticle: Article?
    var miniPlayerTransition: Namespace.ID

    func body(content: Content) -> some View {
        if audioPlayer.currentArticleID != nil {
            content
                .tabViewBottomAccessory {
                    MiniPlayerView { article in
                        miniPlayerPresentedArticle = article
                    }
                    .matchedTransitionSource(id: "miniPlayer", in: miniPlayerTransition)
                }
        } else {
            content
        }
    }
}
