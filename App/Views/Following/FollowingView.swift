import SwiftUI

struct FollowingView: View {

    @Environment(FeedManager.self) var feedManager
    @AppStorage("FeedsList.FeedID") private var savedFeedID: Int = -1
    @AppStorage("FeedsList.ArticleID") private var savedArticleID: Int = -1
    @State private var path = NavigationPath()
    @State private var hasRestored = false
    @Namespace private var cardZoom

    var body: some View {
        NavigationStack(path: $path) {
            FollowingPage()
                .environment(\.navigateToFeed, { feed in path.append(feed) })
                .environment(\.navigateToEphemeralArticle, ephemeralAppender)
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
    }

    private var ephemeralAppender: (EphemeralArticleDestination) -> Void {
        { destination in path.append(destination) }
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
