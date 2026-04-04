import SwiftUI

enum SidebarDestination: Hashable {
    case allArticles
    case section(FeedSection)
    case bookmarks
    case feed(Feed)
    case more
}

struct iPadSidebarView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.openURL) private var openURL
    @AppStorage("YouTube.OpenMode") private var youTubeOpenMode: YouTubeOpenMode = .inAppPlayer
    @Binding var pendingFeedURL: String?
    @Binding var pendingArticleID: Int64?
    @Binding var isInSafeMode: Bool
    @Binding var labsWereDisabled: Bool

    @State private var selectedDestination: SidebarDestination? = .allArticles
    @State private var selectedArticle: Article?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showingAddFeed = false
    @State private var showingOnboarding = false
    @State private var showingSafeModeAlert = false
    @State private var showYouTubeSafari = false
    @State private var pendingYouTubeSafariURL: URL?
    @AppStorage("Onboarding.Completed") private var onboardingCompleted: Bool = false

    @Namespace private var cardZoom

    // Feed management state (mirrored from FeedsListPage)
    @State private var feedToEdit: Feed?
    @State private var feedToDelete: Feed?
    @State private var feedForRules: Feed?

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarContent
                .navigationTitle(String(localized: "Tabs.Home"))
                .toolbarTitleDisplayMode(.inlineLarge)
        } content: {
            Group {
                switch selectedDestination {
                case .allArticles:
                    iPadAllArticlesContent()
                case .section(let section):
                    iPadSectionContent(section: section)
                case .bookmarks:
                    iPadBookmarksContent()
                case .feed(let feed):
                    iPadFeedContent(feed: feed)
                case .more:
                    MoreView()
                case .none:
                    ContentUnavailableView {
                        Label(String(localized: "Sidebar.SelectSection"),
                              systemImage: "sidebar.left")
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } detail: {
            detailContent
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
            if let articleID = pendingArticleID {
                handlePendingArticle(articleID)
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
        .sheet(isPresented: $showYouTubeSafari) {
            if let url = pendingYouTubeSafariURL {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
        .sheet(item: $feedToEdit) { feed in
            FeedEditSheet(feed: feed)
                .environment(feedManager)
                .presentationDetents([.medium, .large])
                .interactiveDismissDisabled()
        }
        .sheet(item: $feedForRules) { feed in
            FeedRulesSheet(feed: feed)
                .environment(feedManager)
                .presentationDetents([.medium, .large])
                .interactiveDismissDisabled()
        }
        .confirmationDialog(
            String(localized: "FeedMenu.Delete.Title"),
            isPresented: Binding(
                get: { feedToDelete != nil },
                set: { if !$0 { feedToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "FeedMenu.Delete.Confirm"), role: .destructive) {
                if let feed = feedToDelete {
                    try? feedManager.deleteFeed(feed)
                    feedToDelete = nil
                }
            }
            Button(String(localized: "Shared.Cancel"), role: .cancel) {
                feedToDelete = nil
            }
        } message: {
            if let feed = feedToDelete {
                Text("FeedMenu.Delete.Message.\(feed.title)")
            }
        }
    }

    // MARK: - Sidebar Content

    private var sidebarContent: some View {
        List(selection: $selectedDestination) {
            Section {
                Label(String(localized: "Shared.AllArticles"), systemImage: "square.stack")
                    .tag(SidebarDestination.allArticles)
                ForEach(availableSections, id: \.self) { section in
                    Label(section.localizedTitle, systemImage: sectionIcon(section))
                        .badge(feedManager.unreadCount(for: section))
                        .tag(SidebarDestination.section(section))
                }
            }

            Section {
                Label(String(localized: "Tabs.Bookmarks"), systemImage: "bookmark")
                    .tag(SidebarDestination.bookmarks)
            }

            Section(String(localized: "Sidebar.Following")) {
                ForEach(feedManager.feeds) { feed in
                    NavigationLink(value: SidebarDestination.feed(feed)) {
                        FeedRowView(feed: feed)
                    }
                    .contextMenu {
                        feedContextMenu(for: feed)
                    }
                }
            }

            Section {
                Label(String(localized: "Tabs.More"), systemImage: "ellipsis")
                    .tag(SidebarDestination.more)
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddFeed = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onChange(of: selectedDestination) {
            selectedArticle = nil
        }
    }

    // MARK: - Detail Content

    @ViewBuilder
    private var detailContent: some View {
        if let article = selectedArticle {
            Group {
                if article.isPodcastEpisode {
                    PodcastEpisodeView(article: article)
                } else if article.isYouTubeURL {
                    YouTubePlayerView(article: article)
                } else {
                    ArticleDetailView(article: article)
                }
            }
        } else {
            ContentUnavailableView {
                Label(String(localized: "Sidebar.SelectArticle"),
                      systemImage: "doc.text")
            } description: {
                Text("Sidebar.SelectArticle.Description")
            }
        }
    }

    // MARK: - Content Views

    @ViewBuilder
    private func iPadAllArticlesContent() -> some View {
        iPadArticleListWrapper {
            AllArticlesView()
        }
    }

    @ViewBuilder
    private func iPadSectionContent(section: FeedSection) -> some View {
        iPadArticleListWrapper {
            HomeSectionView(section: section)
                .navigationTitle(section.localizedTitle)
                .toolbarTitleDisplayMode(.inlineLarge)
        }
    }

    @ViewBuilder
    private func iPadBookmarksContent() -> some View {
        iPadArticleListWrapper {
            iPadBookmarksListView()
        }
    }

    @ViewBuilder
    private func iPadFeedContent(feed: Feed) -> some View {
        iPadArticleListWrapper {
            FeedArticlesView(feed: feed)
        }
    }

    /// Wraps content views with navigation destinations and the iPad article selection
    /// environment, so article taps show in the detail column instead of pushing.
    @ViewBuilder
    private func iPadArticleListWrapper<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .environment(\.navigateToFeed, { feed in
                    selectedDestination = .feed(feed)
                })
                .environment(\.zoomNamespace, cardZoom)
                .navigationDestination(for: Feed.self) { feed in
                    FeedArticlesView(feed: feed)
                        .environment(\.iPadArticleSelection, $selectedArticle)
                        .environment(\.zoomNamespace, cardZoom)
                }
                .environment(\.iPadArticleSelection, $selectedArticle)
        }
    }

    // MARK: - External Opening

    private func shouldOpenExternally(_ article: Article) -> Bool {
        if feedManager.feed(forArticle: article)?.isXFeed == true {
            return true
        }
        if article.isYouTubeURL && youTubeOpenMode == .youTubeApp {
            return true
        }
        return false
    }

    private func openArticleExternally(_ article: Article) {
        feedManager.markRead(article)
        if feedManager.feed(forArticle: article)?.isXFeed == true {
            if let url = URL(string: article.url) {
                openURL(url)
            }
        } else if article.isYouTubeURL && youTubeOpenMode == .youTubeApp {
            YouTubeHelper.openInApp(url: article.url)
        } else if article.isYouTubeURL && youTubeOpenMode == .browser {
            pendingYouTubeSafariURL = URL(string: article.url)
            showYouTubeSafari = true
        }
    }

    private func handlePendingArticle(_ articleID: Int64) {
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            if let article = feedManager.article(byID: articleID) {
                if shouldOpenExternally(article) {
                    openArticleExternally(article)
                } else {
                    selectedArticle = article
                    feedManager.markRead(article)
                }
            }
            pendingArticleID = nil
        }
    }

    // MARK: - Helpers

    private var availableSections: [FeedSection] {
        FeedSection.allCases.filter { feedManager.hasFeeds(for: $0) }
    }

    private func sectionIcon(_ section: FeedSection) -> String {
        switch section {
        case .news: "newspaper"
        case .social: "person.2"
        case .video: "play.rectangle"
        case .audio: "headphones"
        }
    }

    @ViewBuilder
    private func feedContextMenu(for feed: Feed) -> some View {
        Button {
            feedManager.toggleMuted(feed)
        } label: {
            Label(
                feed.isMuted
                    ? String(localized: "FeedMenu.Unmute")
                    : String(localized: "FeedMenu.Mute"),
                systemImage: feed.isMuted ? "bell" : "bell.slash"
            )
        }
        Button {
            feedForRules = feed
        } label: {
            Label(String(localized: "FeedMenu.Rules"),
                  systemImage: "list.bullet.rectangle")
        }
        Divider()
        Button {
            feedToEdit = feed
        } label: {
            Label(String(localized: "FeedMenu.Edit"),
                  systemImage: "pencil")
        }
        Button(role: .destructive) {
            feedToDelete = feed
        } label: {
            Label(String(localized: "FeedMenu.Delete"),
                  systemImage: "trash")
        }
    }
}

// MARK: - iPad Bookmarks List (without its own NavigationStack)

private struct iPadBookmarksListView: View {

    @Environment(FeedManager.self) var feedManager
    @State private var bookmarkedArticles: [Article] = []
    @State private var displayStyle: FeedDisplayStyle

    private var hasImages: Bool {
        bookmarkedArticles.contains { $0.imageURL != nil }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: "Display.DefaultBookmarksStyle")
        let defaultRaw = UserDefaults.standard.string(forKey: "Display.DefaultStyle") ?? FeedDisplayStyle.inbox.rawValue
        let fallback = FeedDisplayStyle(rawValue: defaultRaw) ?? .inbox
        self._displayStyle = State(initialValue: raw.flatMap(FeedDisplayStyle.init(rawValue:)) ?? fallback)
    }

    var body: some View {
        let effectiveStyle = effectiveDisplayStyle
        Group {
            if bookmarkedArticles.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "Bookmarks.Empty.Title"),
                          systemImage: "bookmark")
                } description: {
                    Text("Bookmarks.Empty.Description")
                }
            } else {
                switch effectiveStyle {
                case .inbox:
                    InboxStyleView(articles: bookmarkedArticles)
                case .feed:
                    FeedStyleView(articles: bookmarkedArticles)
                case .magazine:
                    MagazineStyleView(articles: bookmarkedArticles)
                case .compact:
                    CompactStyleView(articles: bookmarkedArticles)
                case .video:
                    VideoStyleView(articles: bookmarkedArticles)
                case .photos:
                    PhotosStyleView(articles: bookmarkedArticles)
                case .podcast:
                    PodcastStyleView(articles: bookmarkedArticles)
                case .timeline:
                    TimelineStyleView(articles: bookmarkedArticles)
                case .cards:
                    CardsStyleView(articles: bookmarkedArticles)
                }
            }
        }
        .navigationTitle(String(localized: "Tabs.Bookmarks"))
        .toolbarTitleDisplayMode(.inlineLarge)
        .scrollContentBackground(.hidden)
        .sakuraBackground()
        .toolbar {
            if !bookmarkedArticles.isEmpty {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Picker(String(localized: "Articles.DisplayStyle"), selection: $displayStyle) {
                            Label(String(localized: "Articles.Style.Inbox"), systemImage: "tray")
                                .tag(FeedDisplayStyle.inbox)
                            Label(String(localized: "Articles.Style.Compact"), systemImage: "list.dash")
                                .tag(FeedDisplayStyle.compact)
                            if hasImages {
                                Label(String(localized: "Articles.Style.Magazine"), systemImage: "rectangle.grid.2x2")
                                    .tag(FeedDisplayStyle.magazine)
                            }
                            Label(String(localized: "Articles.Style.Feed"), systemImage: "newspaper")
                                .tag(FeedDisplayStyle.feed)
                            if hasImages {
                                Label(String(localized: "Articles.Style.Photos"), systemImage: "photo.stack")
                                    .tag(FeedDisplayStyle.photos)
                            }
                            Label(String(localized: "Articles.Style.Timeline"), systemImage: "clock")
                                .tag(FeedDisplayStyle.timeline)
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                    }
                    .menuActionDismissBehavior(.disabled)
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            try? DatabaseManager.shared.removeReadBookmarks()
                            bookmarkedArticles = (try? DatabaseManager.shared.bookmarkedArticles()) ?? []
                        } label: {
                            Label(String(localized: "Bookmarks.DeleteAllRead"),
                                  systemImage: "bookmark.slash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .animation(.smooth.speed(2.0), value: displayStyle)
        .animation(.smooth.speed(2.0), value: bookmarkedArticles)
        .onChange(of: displayStyle) { _, newValue in
            UserDefaults.standard.set(newValue.rawValue, forKey: "Display.DefaultBookmarksStyle")
        }
        .onAppear {
            bookmarkedArticles = (try? DatabaseManager.shared.bookmarkedArticles()) ?? []
        }
        .onChange(of: feedManager.dataRevision) {
            bookmarkedArticles = (try? DatabaseManager.shared.bookmarkedArticles()) ?? []
        }
    }

    private var effectiveDisplayStyle: FeedDisplayStyle {
        if !hasImages && (displayStyle == .magazine || displayStyle == .photos || displayStyle == .cards) {
            return .inbox
        }
        if displayStyle == .podcast {
            return .inbox
        }
        return displayStyle
    }
}

// MARK: - Environment Key for iPad Article Selection

struct iPadArticleSelectionKey: EnvironmentKey {
    static let defaultValue: Binding<Article?>? = nil
}

extension EnvironmentValues {
    var iPadArticleSelection: Binding<Article?>? {
        get { self[iPadArticleSelectionKey.self] }
        set { self[iPadArticleSelectionKey.self] = newValue }
    }
}
