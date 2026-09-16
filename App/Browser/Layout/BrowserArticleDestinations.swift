import SwiftUI
import Hanami

/// The article viewer's destinations, both the stored article and the
/// ephemeral one opened through `sakura://open`.
struct BrowserArticleDestinations: ViewModifier {

    @Environment(FeedManager.self) private var feedManager
    @Binding var path: NavigationPath
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        content
            .navigationDestination(for: Article.self) { article in
                articleDestination(article)
                    .zoomTransition(sourceID: article.id, in: namespace)
                    .environment(\.browserPathToken, .article(article.id))
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
                // Ephemeral articles are not in the database, so there is
                // nothing to rebuild them from. Cleared rather than inherited
                // from the page that pushed this one.
                .environment(\.browserPathToken, nil)
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
    func browserArticleDestinations(
        path: Binding<NavigationPath>,
        namespace: Namespace.ID
    ) -> some View {
        modifier(BrowserArticleDestinations(path: path, namespace: namespace))
    }
}
