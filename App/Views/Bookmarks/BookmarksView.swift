import SwiftUI

struct BookmarksView: View {

    @Environment(FeedManager.self) var feedManager
    @Namespace private var cardZoom

    var body: some View {
        NavigationStack {
            BookmarksContentView()
                .environment(\.zoomNamespace, cardZoom)
                .environment(\.navigateToFeed, { _ in })
                .navigationDestination(for: Feed.self) { feed in
                    FeedArticlesView(feed: feed)
                        .environment(\.zoomNamespace, cardZoom)
                }
                .navigationDestination(for: Article.self) { article in
                    ArticleDestinationView(article: article)
                        .environment(\.zoomNamespace, cardZoom)
                        .zoomTransition(sourceID: article.id, in: cardZoom)
                }
                .navigationDestination(for: EntityDestination.self) { destination in
                    EntityArticlesView(destination: destination)
                        .environment(\.zoomNamespace, cardZoom)
                }
        }
    }
}
