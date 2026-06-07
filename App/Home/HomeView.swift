import SwiftUI
import Hanami

struct HomeView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(TodayManager.self) var todayManager
    @AppStorage("Home.FeedID") var savedFeedID: Int = -1
    @AppStorage("Home.ArticleID") var savedArticleID: Int = -1
    @AppStorage("YouTube.OpenMode") var youTubeOpenMode: YouTubeOpenMode = .inAppPlayer
    @AppStorage("Intelligence.ContentInsights.Enabled") var contentInsightsEnabled: Bool = false
    @Binding var pendingArticleID: Int64?
    @Binding var pendingOpenRequest: OpenArticleRequest?
    @State var path = NavigationPath()
    @State var hasRestored = false
    @State var showYouTubeSafari = false
    @State var selectionStore = HomeSelectionStore()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("Display.MarkAllReadPosition") var markAllReadPosition: MarkAllReadPosition = .top
    @State var pendingYouTubeSafariURL: URL?
    @State var isShowingMarkAllReadConfirmation = false
    @State var isShowingRefreshingFeedsPopover = false
    @State var topTopics: [String] = []
    @State var barConfiguration: HomeBarConfiguration = .load()
    @State var showingWeatherLocationPicker = false
    @State var sectionDisplayMenu = HomeSectionDisplayMenuModel()
    @Namespace private var cardZoom

    var selectedSelection: HomeSelection {
        get { selectionStore.selection }
        nonmutating set { selectionStore.selection = newValue }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                HomeContentArea(
                    selectionStore: selectionStore,
                    tabItems: tabItems,
                    usesPhoneTopBarRedesign: usesPhoneTopBarRedesign,
                    sectionDisplayMenu: sectionDisplayMenu
                )
                .environment(\.zoomNamespace, cardZoom)
                .environment(\.navigateToFeed, { feed in path.append(feed) })
                .environment(\.navigateToEphemeralArticle, ephemeralAppender)
                .environment(\.navigateToSummaryHeadline, { destination in path.append(destination) })
                .environment(\.hidesMarkAllReadToolbar, true)
                .toolbarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .top, spacing: 0) {
                    if tabItems.count > 1, !usesPhoneTopBarRedesign {
                        HomeSectionBarHostView(
                            selectionStore: selectionStore,
                            tabs: tabItems
                        )
                    }
                }
                .overlay(alignment: .top) {
                    HomeRefreshStatusStrip(
                        selectionStore: selectionStore,
                        usesPhoneTopBarRedesign: usesPhoneTopBarRedesign
                    )
                }
            }
            .toolbar {
                if usesPhoneTopBarRedesign {
                    redesignToolbarItems
                } else {
                    nonRedesignToolbarItems
                }
            }
            .navigationDestination(for: Feed.self) { feed in
                FeedArticlesView(feed: feed)
                    .environment(\.zoomNamespace, cardZoom)
                    .environment(\.navigateToEphemeralArticle, ephemeralAppender)
                    .onAppear { savedFeedID = Int(feed.id) }
                    .onDisappear {
                        if path.count < 1 { savedFeedID = -1 }
                    }
            }
            .navigationDestination(for: Article.self) { article in
                ArticleDestinationView(article: article)
                    .environment(\.zoomNamespace, cardZoom)
                    .environment(\.navigateToEphemeralArticle, ephemeralAppender)
                    .environment(\.navigateToFeed, { feed in path.append(feed) })
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
                .environment(\.zoomNamespace, cardZoom)
                .environment(\.navigateToEphemeralArticle, ephemeralAppender)
            }
            .navigationDestination(for: EntityDestination.self) { destination in
                EntityArticlesView(destination: destination)
                    .environment(\.zoomNamespace, cardZoom)
                    .environment(\.navigateToEphemeralArticle, ephemeralAppender)
            }
            .navigationDestination(for: SummaryHeadlineDestination.self) { destination in
                SummaryHeadlinesArticlesView(destination: destination)
                    .environment(\.zoomNamespace, cardZoom)
                    .environment(\.navigateToEphemeralArticle, ephemeralAppender)
                    .zoomTransition(sourceID: destination.zoomTransitionID, in: cardZoom)
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
                        if article.isYouTubeURL {
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
        .sheet(isPresented: $showingWeatherLocationPicker) {
            TodayWeatherLocationSheet()
                .presentationDetents([.large])
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
        .onChange(of: tabItems) {
            validateBarSelection()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                selectionStore.persist()
            }
        }
    }

    var ephemeralAppender: (EphemeralArticleDestination) -> Void {
        { destination in path.append(destination) }
    }
}
