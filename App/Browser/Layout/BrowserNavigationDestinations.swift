import SwiftUI
import Hanami

/// Registers every destination type the app pushes. Applied once per tab, on
/// the stack's root.
struct BrowserNavigationDestinations: ViewModifier {

    @Environment(FeedManager.self) private var feedManager
    @Binding var path: NavigationPath
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        content
            .navigationDestination(for: Feed.self) { feed in
                FeedArticlesView(feed: feed)
                    .browserNavigationEnvironment(path: $path, namespace: namespace)
                    .browserPage(
                        title: feed.title,
                        subtitle: feed.domain,
                        symbolName: "dot.radiowaves.up.forward",
                        feedID: feed.id
                    )
            }
            .navigationDestination(for: Article.self) { article in
                articleDestination(article)
                    .zoomTransition(sourceID: article.id, in: namespace)
            }
            .navigationDestination(for: EphemeralArticleDestination.self) { destination in
                ArticleDestinationView(
                    article: destination.article,
                    overrideMode: destination.mode,
                    overrideTextMode: destination.textMode
                )
                .browserNavigationEnvironment(path: $path, namespace: namespace)
                .browserPage(
                    title: destination.article.title,
                    subtitle: URL(string: destination.article.url)?.host,
                    symbolName: "doc.text"
                )
            }
            .navigationDestination(for: EntityDestination.self) { destination in
                EntityArticlesView(destination: destination)
                    .browserNavigationEnvironment(path: $path, namespace: namespace)
                    .browserPage(title: destination.name, symbolName: "tag")
            }
            .navigationDestination(for: SummaryHeadlineDestination.self) { destination in
                SummaryHeadlinesArticlesView(destination: destination)
                    .browserNavigationEnvironment(path: $path, namespace: namespace)
                    .browserPage(
                        title: String(localized: "Location.Headline", table: "Browser"),
                        symbolName: "sparkles"
                    )
                    .zoomTransition(sourceID: destination.zoomTransitionID, in: namespace)
            }
    }

    @ViewBuilder
    private func articleDestination(_ article: Article) -> some View {
        let feed = feedManager.feed(forArticle: article)
        ArticleDestinationView(article: article)
            .browserNavigationEnvironment(path: $path, namespace: namespace)
            .browserPage(
                title: article.title,
                subtitle: feed?.domain ?? URL(string: article.url)?.host,
                symbolName: "doc.text",
                feedID: feed?.id
            )
    }
}

extension View {
    func browserNavigationDestinations(
        path: Binding<NavigationPath>,
        namespace: Namespace.ID
    ) -> some View {
        modifier(BrowserNavigationDestinations(path: path, namespace: namespace))
    }
}
