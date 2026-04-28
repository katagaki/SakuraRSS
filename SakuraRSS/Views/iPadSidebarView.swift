import SwiftUI

enum SidebarDestination: Hashable {
    case allArticles
    case section(FeedSection)
    case bookmarks
    case topics
    case people
    case list(FeedList)
    case feed(Feed)
    case more
}

struct IPadSidebarView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.openURL) private var openURL
    @AppStorage("YouTube.OpenMode") var youTubeOpenMode: YouTubeOpenMode = .inAppPlayer
    @Binding var pendingFeedURL: String?
    @Binding var pendingArticleID: Int64?
    @Binding var pendingOpenRequest: OpenArticleRequest?

    @State var selectedDestination: SidebarDestination? = .allArticles
    @State var selectedArticle: Article?
    @State var selectedEphemeralDestination: EphemeralArticleDestination?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showingAddFeed = false
    @State private var showingNewList = false
    @State private var showingMore = false
    @State private var showingOnboarding = false
    @State var showYouTubeSafari = false
    @State var pendingYouTubeSafariURL: URL?
    @State private var searchText = ""
    @AppStorage("Onboarding.Completed") private var onboardingCompleted: Bool = false
    @AppStorage("Intelligence.ContentInsights.Enabled") private var contentInsightsEnabled: Bool = false

    @Namespace private var cardZoom

    private var searchResults: [Article] {
        guard !searchText.isEmpty else { return [] }
        return (try? DatabaseManager.shared.searchArticles(query: searchText)) ?? []
    }

    @State private var feedToEdit: Feed?
    @State private var feedToDelete: Feed?
    @State private var feedForRules: Feed?

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
                    case .topics:
                        iPadArticleListWrapper {
                            TopicsView()
                        }
                    case .people:
                        iPadArticleListWrapper {
                            PeopleView()
                        }
                    case .list(let list):
                        iPadListContent(list: list)
                    case .feed(let feed):
                        iPadFeedContent(feed: feed)
                    case .more, .none:
                        ContentUnavailableView {
                            Label(String(localized: "Sidebar.SelectSection", table: "Feeds"),
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
            pendingFeedURL = nil
        } content: {
            AddFeedView(initialURL: pendingFeedURL ?? "")
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
        .onChange(of: pendingOpenRequest) {
            if let request = pendingOpenRequest {
                handlePendingOpenRequest(request)
            }
        }
        .task {
            if let request = pendingOpenRequest {
                handlePendingOpenRequest(request)
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
            String(localized: "FeedMenu.Delete.Title", table: "Feeds"),
            isPresented: Binding(
                get: { feedToDelete != nil },
                set: { if !$0 { feedToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "FeedMenu.Delete.Confirm", table: "Feeds"), role: .destructive) {
                if let feed = feedToDelete {
                    try? feedManager.deleteFeed(feed)
                    feedToDelete = nil
                }
            }
            Button("Shared.Cancel", role: .cancel) {
                feedToDelete = nil
            }
        } message: {
            if let feed = feedToDelete {
                Text(String(localized: "FeedMenu.Delete.Message.\(feed.title)", table: "Feeds"))
            }
        }
        .sheet(item: $listToEdit) { list in
            ListEditSheet(list: list)
                .environment(feedManager)
                .interactiveDismissDisabled()
        }
        .sheet(item: $listForRules) { list in
            ListRulesSheet(list: list)
                .environment(feedManager)
                .interactiveDismissDisabled()
        }
        .confirmationDialog(
            String(localized: "ListMenu.Delete.Title", table: "Lists"),
            isPresented: Binding(
                get: { listToDelete != nil },
                set: { if !$0 { listToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "ListMenu.Delete.Confirm", table: "Lists"), role: .destructive) {
                if let list = listToDelete {
                    feedManager.deleteList(list)
                    listToDelete = nil
                }
            }
            Button("Shared.Cancel", role: .cancel) {
                listToDelete = nil
            }
        } message: {
            if let list = listToDelete {
                Text(String(localized: "ListMenu.Delete.Message.\(list.name)", table: "Lists"))
            }
        }
    }

    // MARK: - Sidebar Content

    private var sidebarContent: some View {
        List(selection: $selectedDestination) {
            Section {
                Label("Shared.AllArticles", systemImage: "square.stack")
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
                Label("Tabs.Bookmarks", systemImage: "bookmark")
                    .tag(SidebarDestination.bookmarks)
            }

            if contentInsightsEnabled {
                Section {
                    Label(String(localized: "Topics.Title", table: "Articles"), systemImage: "number")
                        .tag(SidebarDestination.topics)
                    Label(String(localized: "People.Title", table: "Articles"), systemImage: "person.2")
                        .tag(SidebarDestination.people)
                }
            }

            if !feedManager.lists.isEmpty {
                Section("Tabs.Lists") {
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

            Section(String(localized: "Sidebar.Following", table: "Feeds")) {
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
                Label("Tabs.Profile", systemImage: "person.crop.circle")
                    .tag(SidebarDestination.more)
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, placement: .sidebar, prompt: Text(String(localized: "Prompt", table: "Search")))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingAddFeed = true
                    } label: {
                        Label(String(localized: "Sidebar.AddFeed", table: "Feeds"),
                              systemImage: "dot.radiowaves.up.forward")
                    }
                    Button {
                        showingNewList = true
                    } label: {
                        Label(String(localized: "Sidebar.CreateList", table: "Feeds"),
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
                selectedEphemeralDestination = nil
            }
        }
        .sheet(isPresented: $showingMore) {
            MoreView()
        }
        .sheet(isPresented: $showingNewList) {
            ListEditSheet(list: nil)
                .environment(feedManager)
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
                    selectedEphemeralDestination = nil
                    feedManager.markRead(article)
                }
            }
            pendingArticleID = nil
        }
    }

    // MARK: - Helpers

    private var availableSections: [FeedSection] {
        FeedSection.allCases.filter { $0 != .feeds && feedManager.hasFeeds(for: $0) }
    }
}

// MARK: - IPadSidebarView Content Views

extension IPadSidebarView {

    @ViewBuilder
    var detailContent: some View {
        if let destination = selectedEphemeralDestination {
            ArticleDestinationView(
                article: destination.article,
                overrideMode: destination.mode,
                overrideTextMode: destination.textMode
            )
            .id(destination.article.url)
        } else if let article = selectedArticle {
            ArticleDestinationView(article: article)
                .id(article.id)
        } else {
            ContentUnavailableView {
                Label(String(localized: "Sidebar.SelectArticle", table: "Feeds"),
                      systemImage: "doc.text")
            } description: {
                Text(String(localized: "Sidebar.SelectArticle.Description", table: "Feeds"))
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
            BookmarksContentView()
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
                .navigationDestination(for: EntityDestination.self) { destination in
                    EntityArticlesView(destination: destination)
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
        case .feeds: "newspaper"
        case .podcasts: "headphones"
        case .instagram, .pixelfed: "photo.on.rectangle"
        case .bluesky, .mastodon, .note, .reddit, .x: "person.2"
        case .substack: "envelope"
        case .vimeo, .youtube, .niconico: "play.rectangle"
        }
    }

    @ViewBuilder
    func listContextMenu(for list: FeedList) -> some View {
        Button {
            listToEdit = list
        } label: {
            Label(String(localized: "ListMenu.Edit", table: "Lists"), systemImage: "pencil")
        }
        Button {
            listForRules = list
        } label: {
            Label(String(localized: "ListMenu.Rules", table: "Lists"),
                  systemImage: "list.bullet.rectangle")
        }
        Divider()
        Button(role: .destructive) {
            listToDelete = list
        } label: {
            Label(String(localized: "ListMenu.Delete", table: "Lists"), systemImage: "trash")
        }
    }

    @ViewBuilder
    func feedContextMenu(for feed: Feed) -> some View {
        Button {
            feedManager.toggleMuted(feed)
        } label: {
            Label(
                feed.isMuted
                    ? String(localized: "FeedMenu.Unmute", table: "Feeds")
                    : String(localized: "FeedMenu.Mute", table: "Feeds"),
                systemImage: feed.isMuted ? "bell" : "bell.slash"
            )
        }
        Button {
            feedForRules = feed
        } label: {
            Label(String(localized: "FeedMenu.Rules", table: "Feeds"),
                  systemImage: "list.bullet.rectangle")
        }
        Divider()
        Button {
            feedToEdit = feed
        } label: {
            Label(String(localized: "FeedMenu.Edit", table: "Feeds"),
                  systemImage: "pencil")
        }
        Button(role: .destructive) {
            feedToDelete = feed
        } label: {
            Label(String(localized: "FeedMenu.Delete", table: "Feeds"),
                  systemImage: "trash")
        }
    }
}

// MARK: - iPad Search Results

private struct IPadSearchResultsView: View {
    let searchResults: [Article]

    var body: some View {
        Group {
            if searchResults.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "NoResults.Title", table: "Search"),
                          systemImage: "magnifyingglass")
                } description: {
                    Text(String(localized: "NoResults.Description", table: "Search"))
                }
            } else {
                InboxStyleView(articles: searchResults)
                    .scrollContentBackground(.hidden)
                    .sakuraBackground()
            }
        }
        .navigationTitle("Tabs.Search")
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
