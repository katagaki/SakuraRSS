import SwiftUI
import TipKit

struct MainTabView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #if os(visionOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    @AppStorage("App.SelectedTab") private var selectedTab: AppTab = .home
    @AppStorage("Onboarding.Completed") private var onboardingCompleted: Bool = false
    @AppStorage("Display.UnreadBadgeMode") private var unreadBadgeMode: UnreadBadgeMode = .none
    @Binding var pendingFeedURL: String?
    @Binding var pendingArticleID: Int64?
    @Binding var pendingOpenRequest: OpenArticleRequest?
    @State private var showingAddFeed = false
    @State private var showingOnboarding = false
    private let audioPlayer = AudioPlayer.shared
    private let youTubeSession = YouTubePlayerSession.shared
    private let mediaPresenter = MediaPresenter.shared

    var body: some View {
        Group {
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
        #if os(visionOS)
        .onAppear {
            mediaPresenter.detachedHandler = { item in
                switch item {
                case .youTube(let article):
                    openWindow(id: "YouTubePlayerWindow", value: article.id)
                case .podcast(let article):
                    openWindow(id: "PodcastPlayerWindow", value: article.id)
                }
            }
        }
        #endif
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
                FollowingView()
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
        #if !os(visionOS)
        .tabBarMinimizeBehavior(.onScrollDown)
        #endif
    }

    private var iPhoneTabView: some View {
        tabView
            .miniPlayerAccessory(
                audioPlayer: audioPlayer,
                youTubeSession: youTubeSession,
                mediaPresenter: mediaPresenter
            )
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
