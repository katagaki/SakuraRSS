import SwiftUI

struct HomeView: View {

    @Environment(FeedManager.self) var feedManager
    @AppStorage("Home.FeedID") var savedFeedID: Int = -1
    @AppStorage("Home.ArticleID") var savedArticleID: Int = -1
    @AppStorage("YouTube.OpenMode") var youTubeOpenMode: YouTubeOpenMode = .inAppPlayer
    @Binding var pendingArticleID: Int64?
    @Binding var pendingOpenRequest: OpenArticleRequest?
    @State var path = NavigationPath()
    @State var hasRestored = false
    @State var showYouTubeSafari = false
    @AppStorage("Home.SelectedSection") var selectedSelection: HomeSelection = .section(.today)
    @AppStorage("Display.MarkAllReadPosition") private var markAllReadPosition: MarkAllReadPosition = .top
    @State var pendingYouTubeSafariURL: URL?
    @State private var isShowingMarkAllReadConfirmation = false
    @State var isShowingRefreshingFeedsPopover = false
    @State private var tabFrames: [String: CGRect] = [:]
    @State var topTopics: [String] = []
    @State var barConfiguration: HomeBarConfiguration = .load()
    @Bindable var weatherService: TodayWeatherService = .shared
    @AppStorage("Onboarding.Completed") var onboardingCompleted: Bool = false
    @State var showingWeatherLocationPicker = false
    @Namespace private var cardZoom

    var body: some View {
        NavigationStack(path: $path) {
            AllArticlesView()
                .environment(\.zoomNamespace, cardZoom)
                .environment(\.navigateToFeed, { feed in path.append(feed) })
                .environment(\.navigateToEphemeralArticle, ephemeralAppender)
                .environment(\.hidesMarkAllReadToolbar, true)
                .toolbarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .top, spacing: 0) {
                    HomeSectionBarHostView(
                        selection: $selectedSelection,
                        tabs: tabItems,
                        tabFrames: $tabFrames
                    )
                }
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        principalToolbarLabel
                    }
                    if isTodaySelected, todayRefreshState.hasActiveProgress {
                        ToolbarItemGroup(placement: .topBarLeading) {
                            FeedRefreshProgressDonut(
                                progress: todayRefreshState.progress,
                                onStop: { feedManager.cancelScopedRefresh(scope: "section.all") }
                            )
                        }
                    }
                    if isTodaySelected {
                        ToolbarItem(placement: .topBarTrailing) {
                            weatherToolbarButton
                        }
                        .sharedBackgroundVisibility(.hidden)
                    }
                    if markAllReadPosition == .top, !isTodaySelected {
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
    }

    var ephemeralAppender: (EphemeralArticleDestination) -> Void {
        { destination in path.append(destination) }
    }
}
