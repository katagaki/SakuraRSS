import SwiftUI

struct ListsView: View {

    @Environment(FeedManager.self) var feedManager
    @Namespace private var cardZoom

    var body: some View {
        NavigationStack {
            ListsPage()
                .environment(\.zoomNamespace, cardZoom)
                .navigationDestination(for: FeedList.self) { list in
                    ListDetailView(list: list)
                        .environment(\.zoomNamespace, cardZoom)
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
                    .zoomTransition(sourceID: article.id, in: cardZoom)
                }
        }
    }
}
