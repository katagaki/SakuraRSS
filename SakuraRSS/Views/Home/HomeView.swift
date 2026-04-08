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
    @State private var showingMore = false
    @State private var pendingYouTubeSafariURL: URL?
    @Namespace private var cardZoom
    @Namespace private var moreNamespace

    var body: some View {
        NavigationStack(path: $path) {
            AllArticlesView()
                .environment(\.zoomNamespace, cardZoom)
                .environment(\.navigateToFeed, { feed in path.append(feed) })
                .toolbar {
                    ToolbarItemGroup(placement: .topBarLeading) {
                        Button {
                            showingMore = true
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                        .matchedTransitionSource(id: "more", in: moreNamespace)
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
                    Group {
                        if article.isPodcastEpisode {
                            PodcastEpisodeView(article: article)
                        } else if article.isYouTubeURL {
                            YouTubePlayerView(article: article)
                        } else {
                            ArticleDetailView(article: article)
                        }
                    }
                    .zoomTransition(sourceID: article.id, in: cardZoom)
                    .onAppear { savedArticleID = Int(article.id) }
                    .onDisappear { savedArticleID = -1 }
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
        .sheet(isPresented: $showingMore) {
            MoreView()
                .navigationTransition(.zoom(sourceID: "more", in: moreNamespace))
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
