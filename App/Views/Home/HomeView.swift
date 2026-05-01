import SwiftUI

struct HomeView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.openURL) private var openURL
    @AppStorage("Home.FeedID") private var savedFeedID: Int = -1
    @AppStorage("Home.ArticleID") private var savedArticleID: Int = -1
    @AppStorage("YouTube.OpenMode") private var youTubeOpenMode: YouTubeOpenMode = .inAppPlayer
    @Binding var pendingArticleID: Int64?
    @Binding var pendingOpenRequest: OpenArticleRequest?
    @State private var path = NavigationPath()
    @State private var hasRestored = false
    @State private var showYouTubeSafari = false
    @AppStorage("Home.SelectedSection") private var selectedSelection: HomeSelection = .section(.all)
    @AppStorage("Display.MarkAllReadPosition") private var markAllReadPosition: MarkAllReadPosition = .top
    @State private var pendingYouTubeSafariURL: URL?
    @State private var isShowingMarkAllReadConfirmation = false
    @State private var tabFrames: [String: CGRect] = [:]
    @State private var topTopics: [String] = []
    @State private var barConfiguration: HomeBarConfiguration = .load()
    @Namespace private var cardZoom

    var body: some View {
        NavigationStack(path: $path) {
            AllArticlesView()
                .environment(\.zoomNamespace, cardZoom)
                .environment(\.navigateToFeed, { feed in path.append(feed) })
                .environment(\.hidesMarkAllReadToolbar, true)
                .toolbarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .top, spacing: 0) {
                    TodayTopBarView(
                        selection: $selectedSelection,
                        tabs: tabItems,
                        tabFrames: $tabFrames
                    )
                }
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text(principalText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if markAllReadPosition == .top {
                        ToolbarItemGroup(placement: .topBarLeading) {
                            Button {
                                isShowingMarkAllReadConfirmation = true
                            } label: {
                                Image(systemName: "envelope.open")
                                    .font(.system(size: 14.0))
                            }
                            .popover(isPresented: $isShowingMarkAllReadConfirmation) {
                                VStack(spacing: 12) {
                                    Text(String(localized: "MarkAllRead.Confirm", table: "Articles"))
                                        .font(.body)
                                    Button {
                                        performMarkAllRead()
                                        isShowingMarkAllReadConfirmation = false
                                    } label: {
                                        Text(String(localized: "MarkAllRead", table: "Articles"))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 6)
                                    }
                                    .buttonStyle(.bordered)
                                }
                                .padding(20)
                                .presentationCompactAdaptation(.popover)
                            }
                        }
                    }
                }
                .navigationDestination(for: Feed.self) { feed in
                    FeedArticlesView(feed: feed)
                        .environment(\.zoomNamespace, cardZoom)
                        .onAppear { savedFeedID = Int(feed.id) }
                        .onDisappear {
                            if path.count < 1 { savedFeedID = -1 }
                        }
                }
                .navigationDestination(for: Article.self) { article in
                    ArticleDestinationView(article: article)
                        .environment(\.zoomNamespace, cardZoom)
                        .zoomTransition(sourceID: article.id, in: cardZoom)
                        .onAppear { savedArticleID = Int(article.id) }
                        .onDisappear { savedArticleID = -1 }
                }
                .navigationDestination(for: EphemeralArticleDestination.self) { destination in
                    ArticleDestinationView(
                        article: destination.article,
                        overrideMode: destination.mode,
                        overrideTextMode: destination.textMode
                    )
                }
                .navigationDestination(for: EntityDestination.self) { destination in
                    EntityArticlesView(destination: destination)
                        .environment(\.zoomNamespace, cardZoom)
                }
        }
        .onChange(of: path.count) {
            if path.isEmpty {
                savedFeedID = -1
                savedArticleID = -1
            }
        }
        .onChange(of: feedManager.feeds) {
            if !hasRestored {
                restorePath()
            }
        }
        .onAppear {
            if !hasRestored {
                restorePath()
            }
        }
        .onChange(of: pendingArticleID) {
            if let articleID = pendingArticleID {
                path = NavigationPath()
                Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    guard pendingArticleID == articleID else { return }
                    if let article = feedManager.article(byID: articleID) {
                        if feedManager.feed(forArticle: article)?.isXFeed == true
                            || feedManager.feed(forArticle: article)?.isInstagramFeed == true {
                            if let url = URL(string: article.url) {
                                feedManager.markRead(article)
                                openURL(url)
                            }
                        } else if article.isYouTubeURL {
                            feedManager.markRead(article)
                            switch youTubeOpenMode {
                            case .inAppPlayer:
                                MediaPresenter.shared.presentYouTube(article)
                            case .youTubeApp:
                                YouTubeHelper.openInApp(url: article.url)
                            case .browser:
                                pendingYouTubeSafariURL = URL(string: article.url)
                                showYouTubeSafari = true
                            }
                        } else if article.isPodcastEpisode {
                            feedManager.markRead(article)
                            MediaPresenter.shared.presentPodcast(article)
                        } else {
                            path.append(article)
                        }
                    }
                    pendingArticleID = nil
                }
            }
        }
        .sheet(isPresented: $showYouTubeSafari) {
            if let url = pendingYouTubeSafariURL {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
        .onChange(of: pendingOpenRequest) {
            if pendingOpenRequest != nil {
                handlePendingOpenRequestIfNeeded()
            }
        }
        .task {
            // Cold-launch from the Open Article extension sets the request
            // before this view mounts, so `onChange` would never fire.
            handlePendingOpenRequestIfNeeded()
        }
        .task(id: barConfiguration) {
            await loadTopTopicsIfNeeded()
        }
        .onChange(of: feedManager.dataRevision) {
            Task { await loadTopTopicsIfNeeded() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .homeBarConfigurationDidChange)) { _ in
            reloadBarConfiguration()
        }
    }

    private var principalText: String {
        let scopedState = feedManager.scopedRefreshes[currentScopeKey]
        if let scopedState, scopedState.hasActiveProgress {
            return String(
                localized: "Home.Refreshing \(scopedState.completed) \(scopedState.total)",
                table: "Home"
            )
        }
        if feedManager.isLoading && feedManager.hasActiveRefreshProgress {
            return String(
                localized: "Home.Refreshing \(feedManager.refreshCompleted) \(feedManager.refreshTotal)",
                table: "Home"
            )
        }
        return formattedDate
    }

    private var currentScopeKey: String {
        switch selectedSelection {
        case .section(let section):
            if let feedSection = section.feedSection {
                return "section.\(feedSection.rawValue)"
            }
            return "section.all"
        case .list(let id):
            return "list.\(id)"
        case .topic(let name):
            return "topic.\(name)"
        }
    }

    private var formattedDate: String {
        let relative: String
        let scopedDate = feedManager.scopedLastRefreshedAt[currentScopeKey]
        if let date = scopedDate ?? feedManager.lastRefreshedAt {
            relative = date.formatted(.relative(presentation: .named))
        } else {
            relative = Date().formatted(
                .dateTime
                    .weekday(.wide)
                    .month(.abbreviated)
                    .day()
            )
        }
        return String(localized: "Home.LastUpdated \(relative)", table: "Home")
    }

    private func performMarkAllRead() {
        switch selectedSelection {
        case .section(let section):
            if let feedSection = section.feedSection {
                feedManager.markAllRead(for: feedSection)
            } else {
                feedManager.markAllRead()
            }
        case .list(let id):
            if let list = feedManager.lists.first(where: { $0.id == id }) {
                feedManager.markAllRead(for: list)
            }
        case .topic(let name):
            let entries = feedManager.preloadedArticleEntries(forTopic: name)
            let articles = feedManager.articles(withPreloadedIDs: entries.map(\.id))
            for article in articles where !feedManager.isRead(article) {
                feedManager.markRead(article)
            }
        }
    }

    private var availableSections: [HomeSection] {
        HomeSection.allCases.filter { section in
            guard let feedSection = section.feedSection else { return true }
            return feedManager.hasFeeds(for: feedSection)
        }
    }

    private var tabItems: [TodayTabItem] {
        TodayTabItem.items(
            sections: availableSections,
            lists: feedManager.lists,
            topics: topTopics,
            configuration: barConfiguration
        )
    }

    private func reloadBarConfiguration() {
        barConfiguration = .load()
    }

    private func loadTopTopicsIfNeeded() async {
        guard barConfiguration.enabledItems.contains(.topics) else {
            topTopics = []
            validateTopicSelection()
            return
        }
        let limit = barConfiguration.topicCount.rawValue
        let database = DatabaseManager.shared
        let topics: [String] = await Task.detached {
            let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 3600)
            let results = (try? database.topEntities(
                types: ["organization", "place"],
                since: sevenDaysAgo,
                limit: limit
            )) ?? []
            return results.map(\.name)
        }.value
        topTopics = topics
        validateTopicSelection()
    }

    private func validateTopicSelection() {
        if case .topic(let name) = selectedSelection, !topTopics.contains(name) {
            selectedSelection = .section(.all)
        }
    }

    private func handlePendingOpenRequestIfNeeded() {
        guard let request = pendingOpenRequest else { return }
        handlePendingOpenRequest(request)
    }

    private func handlePendingOpenRequest(_ request: OpenArticleRequest) {
        // Suppress saved-state restoration that would otherwise stomp on our
        // navigation push when launched cold from the extension.
        hasRestored = true
        let article = Article.ephemeral(url: request.url, title: request.url)
        if article.isYouTubeURL {
            switch youTubeOpenMode {
            case .inAppPlayer:
                MediaPresenter.shared.presentYouTube(article)
            case .youTubeApp:
                YouTubeHelper.openInApp(url: article.url)
            case .browser:
                pendingYouTubeSafariURL = URL(string: article.url)
                showYouTubeSafari = true
            }
        } else {
            path.append(EphemeralArticleDestination(
                article: article, mode: request.mode, textMode: request.textMode
            ))
        }
        pendingOpenRequest = nil
    }

    private func restorePath() {
        guard !feedManager.feeds.isEmpty else { return }
        hasRestored = true

        if savedFeedID >= 0,
           let feed = feedManager.feeds.first(where: { $0.id == Int64(savedFeedID) }) {
            path.append(feed)
            if savedArticleID >= 0,
               let article = feedManager.article(byID: Int64(savedArticleID)) {
                appendArticle(article)
            }
        } else if savedArticleID >= 0,
                  let article = feedManager.article(byID: Int64(savedArticleID)) {
            appendArticle(article)
        }
    }

    private func appendArticle(_ article: Article) {
        if article.isPodcastEpisode {
            MediaPresenter.shared.presentPodcast(article)
            savedArticleID = -1
        } else if article.isYouTubeURL {
            // Restoration for YouTube articles is skipped since the player
            // sheet doesn't survive app relaunch.
            savedArticleID = -1
        } else {
            path.append(article)
        }
    }
}
