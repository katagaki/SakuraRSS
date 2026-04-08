import SwiftUI

enum SidebarDestination: Hashable {
    case allArticles
    case section(FeedSection)
    case bookmarks
    case list(FeedList)
    case feed(Feed)
    case more
}

struct IPadSidebarView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.openURL) private var openURL
    @AppStorage("YouTube.OpenMode") private var youTubeOpenMode: YouTubeOpenMode = .inAppPlayer
    @Binding var pendingFeedURL: String?
    @Binding var pendingArticleID: Int64?

    @State private var selectedDestination: SidebarDestination? = .allArticles
    @State private var selectedArticle: Article?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showingAddFeed = false
    @State private var showingNewList = false
    @State private var showingMore = false
    @State private var lastAddedFeedURL: String?
    @State private var showingOnboarding = false
    @State private var showYouTubeSafari = false
    @State private var pendingYouTubeSafariURL: URL?
    @State private var searchText = ""
    @AppStorage("Onboarding.Completed") private var onboardingCompleted: Bool = false

    @Namespace private var cardZoom

    private var searchResults: [Article] {
        guard !searchText.isEmpty else { return [] }
        return (try? DatabaseManager.shared.searchArticles(query: searchText)) ?? []
    }

    // Feed management state (mirrored from FeedsListPage)
    @State private var feedToEdit: Feed?
    @State private var feedToDelete: Feed?
    @State private var feedForRules: Feed?

    // List management state
    @State private var listToEdit: FeedList?
    @State private var listForRules: FeedList?
    @State private var listToDelete: FeedList?

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarContent
        } content: {
            Group {
                if !searchText.isEmpty {
                    iPadArticleListWrapper {
                        IPadSearchResultsView(searchResults: searchResults)
                    }
                } else {
                    switch selectedDestination {
                    case .allArticles:
                        iPadAllArticlesContent()
                    case .section(let section):
                        iPadSectionContent(section: section)
                    case .bookmarks:
                        iPadBookmarksContent()
                    case .list(let list):
                        iPadListContent(list: list)
                    case .feed(let feed):
                        iPadFeedContent(feed: feed)
                    case .more, .none:
                        ContentUnavailableView {
                            Label(String(localized: "Sidebar.SelectSection"),
                                  systemImage: "sidebar.left")
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } detail: {
            detailContent
        }
        .sheet(isPresented: $showingAddFeed) {
            if let url = lastAddedFeedURL,
               let feed = feedManager.feeds.first(where: { $0.url == url }) {
                lastAddedFeedURL = nil
                selectedDestination = .feed(feed)
                Task {
                    try? await feedManager.refreshFeed(feed)
                }
            }
            pendingFeedURL = nil
        } content: {
            AddFeedView(initialURL: pendingFeedURL ?? "", onFeedAdded: { url in
                lastAddedFeedURL = url
            })
                .environment(feedManager)
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
        .sheet(item: $listToEdit) { list in
            ListEditSheet(list: list)
                .environment(feedManager)
                .presentationDetents([.medium, .large])
                .interactiveDismissDisabled()
        }
        .sheet(item: $listForRules) { list in
            ListRulesSheet(list: list)
                .environment(feedManager)
                .presentationDetents([.medium, .large])
                .interactiveDismissDisabled()
        }
        .confirmationDialog(
            String(localized: "ListMenu.Delete.Title"),
            isPresented: Binding(
                get: { listToDelete != nil },
                set: { if !$0 { listToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "ListMenu.Delete.Confirm"), role: .destructive) {
                if let list = listToDelete {
                    feedManager.deleteList(list)
                    listToDelete = nil
                }
            }
            Button(String(localized: "Shared.Cancel"), role: .cancel) {
                listToDelete = nil
            }
        } message: {
            if let list = listToDelete {
                Text("ListMenu.Delete.Message.\(list.name)")
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
                    HStack {
                        Label(section.localizedTitle, systemImage: sectionIcon(section))
                        Spacer()
                        let count = feedManager.unreadCount(for: section)
                        if count > 0 {
                            Text("\(count)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.tertiary)
                                .foregroundStyle(.secondary)
                                .clipShape(Capsule())
                        }
                    }
                    .tag(SidebarDestination.section(section))
                }
            }

            Section {
                Label(String(localized: "Tabs.Bookmarks"), systemImage: "bookmark")
                    .tag(SidebarDestination.bookmarks)
            }

            if !feedManager.lists.isEmpty {
                Section(String(localized: "Tabs.Lists")) {
                    ForEach(feedManager.lists) { list in
                        HStack {
                            Label(list.name, systemImage: list.icon)
                            Spacer()
                            let count = feedManager.unreadCount(for: list)
                            if count > 0 {
                                Text("\(count)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(.tertiary)
                                    .foregroundStyle(.secondary)
                                    .clipShape(Capsule())
                            }
                        }
                        .tag(SidebarDestination.list(list))
                        .contextMenu {
                            listContextMenu(for: list)
                        }
                    }
                }
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
        .searchable(text: $searchText, placement: .sidebar, prompt: Text("Search.Prompt"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingAddFeed = true
                    } label: {
                        Label(String(localized: "Sidebar.AddFeed"),
                              systemImage: "dot.radiowaves.up.forward")
                    }
                    Button {
                        showingNewList = true
                    } label: {
                        Label(String(localized: "Sidebar.CreateList"),
                              systemImage: "square.fill.text.grid.1x2")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onChange(of: selectedDestination) { oldValue, newValue in
            if newValue == .more {
                showingMore = true
                selectedDestination = oldValue
            } else {
                selectedArticle = nil
            }
        }
        .sheet(isPresented: $showingMore) {
            MoreView()
        }
        .sheet(isPresented: $showingNewList) {
            ListEditSheet(list: nil)
                .environment(feedManager)
                .presentationDetents([.medium, .large])
                .interactiveDismissDisabled()
        }
    }

    // MARK: - External Opening

    func shouldOpenExternally(_ article: Article) -> Bool {
        if feedManager.feed(forArticle: article)?.isXFeed == true
            || feedManager.feed(forArticle: article)?.isInstagramFeed == true {
            return true
        }
        if article.isYouTubeURL && youTubeOpenMode == .youTubeApp {
            return true
        }
        return false
    }

    func openArticleExternally(_ article: Article) {
        feedManager.markRead(article)
        if feedManager.feed(forArticle: article)?.isXFeed == true
            || feedManager.feed(forArticle: article)?.isInstagramFeed == true {
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

    func handlePendingArticle(_ articleID: Int64) {
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
}

// MARK: - IPadSidebarView Content Views

extension IPadSidebarView {

    @ViewBuilder
    var detailContent: some View {
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
            .id(article.id)
        } else {
            ContentUnavailableView {
                Label(String(localized: "Sidebar.SelectArticle"),
                      systemImage: "doc.text")
            } description: {
                Text("Sidebar.SelectArticle.Description")
            }
        }
    }

    @ViewBuilder
    func iPadAllArticlesContent() -> some View {
        iPadArticleListWrapper {
            AllArticlesView()
        }
    }

    @ViewBuilder
    func iPadSectionContent(section: FeedSection) -> some View {
        iPadArticleListWrapper {
            HomeSectionView(section: section)
                .navigationTitle(section.localizedTitle)
                .toolbarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    func iPadBookmarksContent() -> some View {
        iPadArticleListWrapper {
            IPadBookmarksListView()
        }
    }

    @ViewBuilder
    func iPadFeedContent(feed: Feed) -> some View {
        iPadArticleListWrapper {
            FeedArticlesView(feed: feed)
        }
        .id(feed.id)
    }

    @ViewBuilder
    func iPadListContent(list: FeedList) -> some View {
        iPadArticleListWrapper {
            ListSectionView(list: list)
                .navigationTitle(list.name)
                .toolbarTitleDisplayMode(.inline)
        }
        .id(list.id)
    }

    @ViewBuilder
    func iPadArticleListWrapper<Content: View>(@ViewBuilder content: () -> Content) -> some View {
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
}

// MARK: - IPadSidebarView Helpers

extension IPadSidebarView {

    func sectionIcon(_ section: FeedSection) -> String {
        switch section {
        case .news: "newspaper"
        case .social: "person.2"
        case .video: "play.rectangle"
        case .audio: "headphones"
        }
    }

    @ViewBuilder
    func listContextMenu(for list: FeedList) -> some View {
        Button {
            listToEdit = list
        } label: {
            Label(String(localized: "ListMenu.Edit"), systemImage: "pencil")
        }
        Button {
            listForRules = list
        } label: {
            Label(String(localized: "ListMenu.Rules"),
                  systemImage: "list.bullet.rectangle")
        }
        Divider()
        Button(role: .destructive) {
            listToDelete = list
        } label: {
            Label(String(localized: "ListMenu.Delete"), systemImage: "trash")
        }
    }

    @ViewBuilder
    func feedContextMenu(for feed: Feed) -> some View {
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

private struct IPadBookmarksListView: View {

    @Environment(FeedManager.self) var feedManager
    @State private var bookmarkedArticles: [Article] = []
    @State private var displayStyle: FeedDisplayStyle
    @State private var showingDeleteReadAlert = false

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
                DisplayStyleContentView(
                    style: effectiveStyle,
                    articles: bookmarkedArticles
                )
            }
        }
        .navigationTitle(String(localized: "Tabs.Bookmarks"))
        .toolbarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .sakuraBackground()
        .toolbar {
            if !bookmarkedArticles.isEmpty {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingDeleteReadAlert = true
                    } label: {
                        Image(systemName: "bookmark.slash")
                    }
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        DisplayStylePicker(
                            displayStyle: $displayStyle,
                            hasImages: hasImages,
                            showCards: false
                        )
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                    }
                    .menuActionDismissBehavior(.disabled)
                }
            }
        }
        .animation(.smooth.speed(2.0), value: displayStyle)
        .animation(.smooth.speed(2.0), value: bookmarkedArticles)
        .onChange(of: displayStyle) { _, newValue in
            UserDefaults.standard.set(newValue.rawValue, forKey: "Display.DefaultBookmarksStyle")
        }
        .confirmationDialog(
            String(localized: "Bookmarks.DeleteAllRead"),
            isPresented: $showingDeleteReadAlert,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Bookmarks.DeleteAllRead.Confirm"), role: .destructive) {
                try? DatabaseManager.shared.removeReadBookmarks()
                bookmarkedArticles = (try? DatabaseManager.shared.bookmarkedArticles()) ?? []
            }
            Button(String(localized: "Shared.Cancel"), role: .cancel) { }
        } message: {
            Text("Bookmarks.DeleteAllRead.Message")
        }
        .onAppear {
            bookmarkedArticles = (try? DatabaseManager.shared.bookmarkedArticles()) ?? []
        }
        .onChange(of: feedManager.dataRevision) {
            bookmarkedArticles = (try? DatabaseManager.shared.bookmarkedArticles()) ?? []
        }
    }

    private var effectiveDisplayStyle: FeedDisplayStyle {
        if !hasImages && displayStyle.requiresImages {
            return .inbox
        }
        if displayStyle == .podcast {
            return .inbox
        }
        return displayStyle
    }
}

// MARK: - iPad Search Results

private struct IPadSearchResultsView: View {
    let searchResults: [Article]

    var body: some View {
        Group {
            if searchResults.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "Search.NoResults.Title"),
                          systemImage: "magnifyingglass")
                } description: {
                    Text("Search.NoResults.Description")
                }
            } else {
                InboxStyleView(articles: searchResults)
                    .scrollContentBackground(.hidden)
                    .sakuraBackground()
            }
        }
        .navigationTitle(String(localized: "Tabs.Search"))
        .toolbarTitleDisplayMode(.inline)
    }
}

// MARK: - Environment Key for iPad Article Selection

struct IPadArticleSelectionKey: EnvironmentKey {
    static let defaultValue: Binding<Article?>? = nil
}

extension EnvironmentValues {
    var iPadArticleSelection: Binding<Article?>? {
        get { self[IPadArticleSelectionKey.self] }
        set { self[IPadArticleSelectionKey.self] = newValue }
    }
}
