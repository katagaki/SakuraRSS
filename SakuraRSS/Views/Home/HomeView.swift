import SwiftUI

struct HomeView: View {

    @Environment(FeedManager.self) var feedManager
    @AppStorage("homeFeedID") private var savedFeedID: Int = -1
    @AppStorage("homeArticleID") private var savedArticleID: Int = -1
    @State private var path = NavigationPath()
    @State private var hasRestored = false

    var body: some View {
        NavigationStack(path: $path) {
            AllArticlesView()
                .navigationDestination(for: Feed.self) { feed in
                    FeedArticlesView(feed: feed)
                        .onAppear { savedFeedID = Int(feed.id) }
                        .onDisappear {
                            if path.count < 1 { savedFeedID = -1 }
                        }
                }
                .navigationDestination(for: Article.self) { article in
                    ArticleDetailView(article: article)
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
