import SwiftUI

struct HomeView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.openURL) private var openURL
    @AppStorage("Home.FeedID") private var savedFeedID: Int = -1
    @AppStorage("Home.ArticleID") private var savedArticleID: Int = -1
    @AppStorage("YouTube.OpenMode") private var youTubeOpenMode: YouTubeOpenMode = .inAppPlayer
    @Binding var pendingArticleID: Int64?
    @State private var path = NavigationPath()
    @State private var hasRestored = false
    @State private var showYouTubeSafari = false
    @AppStorage("Display.MarkAllReadPosition") private var markAllReadPosition: MarkAllReadPosition = .bottom
    @AppStorage("Home.SelectedSection") private var selectedSelection: HomeSelection = .section(.feed)
    @State private var isShowingMarkAllReadConfirmation = false
    @State private var pendingYouTubeSafariURL: URL?
    @Namespace private var cardZoom

    var body: some View {
        NavigationStack(path: $path) {
            AllArticlesView()
                .environment(\.zoomNamespace, cardZoom)
                .environment(\.navigateToFeed, { feed in path.append(feed) })
                .environment(\.hidesMarkAllReadToolbar, true)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarLeading) {
                        if feedManager.isLoading && feedManager.refreshTotal > 0 {
                            FeedRefreshProgressDonut(
                                progress: feedManager.refreshProgress
                            )
                        }
                    }
                    .sharedBackgroundVisibility(.hidden)
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
                                path.append(article)
                            case .youTubeApp:
                                YouTubeHelper.openInApp(url: article.url)
                            case .browser:
                                pendingYouTubeSafariURL = URL(string: article.url)
                                showYouTubeSafari = true
                            }
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
    }

    private func performMarkAllRead() {
        switch selectedSelection {
        case .section(let section):
            if let feedSection = section.feedSection {
                feedManager.markAllRead(for: feedSection)
            } else {
                feedManager.markAllRead()
            }
        case .bookmarks:
            break
        case .list(let id):
            if let list = feedManager.lists.first(where: { $0.id == id }) {
                feedManager.markAllRead(for: list)
            }
        }
    }

    private func restorePath() {
        guard !feedManager.feeds.isEmpty else { return }
        hasRestored = true

        if savedFeedID >= 0,
           let feed = feedManager.feeds.first(where: { $0.id == Int64(savedFeedID) }) {
            path.append(feed)
            if savedArticleID >= 0,
               let article = feedManager.article(byID: Int64(savedArticleID)) {
                path.append(article)
            }
        } else if savedArticleID >= 0,
                  let article = feedManager.article(byID: Int64(savedArticleID)) {
            path.append(article)
        }
    }
}
