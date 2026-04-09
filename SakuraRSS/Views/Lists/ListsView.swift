import SwiftUI

struct ListsView: View {

    @Environment(FeedManager.self) var feedManager
    @Namespace private var cardZoom

    var body: some View {
        NavigationStack {
            ListsPage()
                .environment(\.zoomNamespace, cardZoom)
                .navigationDestination(for: FeedList.self) { list in
                    ListSectionView(list: list)
                        .environment(\.zoomNamespace, cardZoom)
                        .environment(\.navigateToFeed, { _ in })
                }
                .navigationDestination(for: Feed.self) { feed in
                    FeedArticlesView(feed: feed)
                        .environment(\.zoomNamespace, cardZoom)
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
