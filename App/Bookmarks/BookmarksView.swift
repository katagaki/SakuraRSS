import SwiftUI
import Hanami

struct BookmarksView: View {

    @Environment(FeedManager.self) var feedManager
    @Namespace private var cardZoom
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            BookmarksContentView()
                .environment(\.zoomNamespace, cardZoom)
                .environment(\.navigateToFeed, { feed in path.append(feed) })
                .navigationDestination(for: Feed.self) { feed in
                    FeedArticlesView(feed: feed)
                        .environment(\.zoomNamespace, cardZoom)
                        .environment(\.navigateToFeed, { feed in path.append(feed) })
                }
                .navigationDestination(for: Article.self) { article in
                    ArticleDestinationView(article: article)
                        .environment(\.zoomNamespace, cardZoom)
                        .environment(\.navigateToFeed, { feed in path.append(feed) })
                        .zoomTransition(sourceID: article.id, in: cardZoom)
                }
                .navigationDestination(for: EntityDestination.self) { destination in
                    EntityArticlesView(destination: destination)
                        .environment(\.zoomNamespace, cardZoom)
                }
        }
    }
}
