#if targetEnvironment(macCatalyst)
import SwiftUI
import Hanami

struct DetachedFeedNavigationStack<Root: View>: View {

    @Environment(FeedManager.self) private var feedManager
    @State private var path = NavigationPath()
    @State private var youTubeSession = YouTubePlayerSession()
    @State private var audioPlayer = AudioPlayer()
    @Namespace private var cardZoom
    @ViewBuilder let root: () -> Root

    var body: some View {
        ZStack {
            FreeResizabilityHelper()
                .frame(width: 0, height: 0)
            NavigationStack(path: $path) {
                root()
                    .environment(\.navigateToFeed) { feed in path.append(feed) }
                    .environment(\.navigateToEphemeralArticle) { destination in path.append(destination) }
                    .environment(\.navigateToSummaryHeadline) { destination in path.append(destination) }
                    .environment(\.zoomNamespace, cardZoom)
                    .navigationDestination(for: Feed.self) { feed in
                        FeedArticlesView(feed: feed)
                            .environment(\.navigateToEphemeralArticle) { path.append($0) }
                            .environment(\.zoomNamespace, cardZoom)
                    }
                    .navigationDestination(for: Article.self) { article in
                        ArticleDestinationView(article: article)
                            .environment(\.navigateToFeed) { path.append($0) }
                            .environment(\.navigateToEphemeralArticle) { path.append($0) }
                            .environment(\.zoomNamespace, cardZoom)
                            .zoomTransition(sourceID: article.id, in: cardZoom)
                    }
                    .navigationDestination(for: EphemeralArticleDestination.self) { destination in
                        ArticleDestinationView(
                            article: destination.article,
                            overrideMode: destination.mode,
                            overrideTextMode: destination.textMode
                        )
                        .environment(\.navigateToEphemeralArticle) { path.append($0) }
                        .environment(\.zoomNamespace, cardZoom)
                    }
                    .navigationDestination(for: EntityDestination.self) { destination in
                        EntityArticlesView(destination: destination)
                            .environment(\.navigateToEphemeralArticle) { path.append($0) }
                            .environment(\.zoomNamespace, cardZoom)
                    }
                    .navigationDestination(for: SummaryHeadlineDestination.self) { destination in
                        SummaryHeadlinesArticlesView(destination: destination)
                            .environment(\.navigateToEphemeralArticle) { path.append($0) }
                            .environment(\.zoomNamespace, cardZoom)
                            .zoomTransition(sourceID: destination.zoomTransitionID, in: cardZoom)
                    }
            }
            .compatibleSoftScrollEdgeEffectStyle()
            .environment(\.youTubePlayerSession, youTubeSession)
            .environment(\.podcastAudioPlayer, audioPlayer)
        }
        .onDisappear {
            youTubeSession.clear()
            audioPlayer.stop()
        }
    }
}
#endif
