import SwiftUI

struct FeedListView: View {

    @Environment(FeedManager.self) var feedManager
    @AppStorage("FeedsList.FeedID") private var savedFeedID: Int = -1
    @AppStorage("FeedsList.ArticleID") private var savedArticleID: Int = -1
    @State private var path = NavigationPath()
    @State private var hasRestored = false
    @State private var activeStyle: FeedDisplayStyle = .inbox
    @Namespace private var cardZoom

    var body: some View {
        NavigationStack(path: $path) {
            FeedsListPage { feed in
                    path.append(feed)
                }
                .navigationDestination(for: Feed.self) { feed in
                    FeedArticlesView(feed: feed)
                        .environment(\.cardZoomNamespace, cardZoom)
                        .onAppear { savedFeedID = Int(feed.id) }
                        .onDisappear {
                            if path.count < 1 { savedFeedID = -1 }
                        }
                }
                .navigationDestination(for: Article.self) { article in
                    Group {
                        if article.isPodcastEpisode {
                            PodcastEpisodeView(article: article)
                        } else {
                            ArticleDetailView(article: article)
                        }
                    }
                    .conditionalZoomTransition(isCards: activeStyle == .cards,
                                               sourceID: article.id, in: cardZoom)
                    .onAppear { savedArticleID = Int(article.id) }
                    .onDisappear { savedArticleID = -1 }
                }
        }
        .onPreferenceChange(ActiveDisplayStyleKey.self) { style in
            activeStyle = style
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
        }
    }
}
