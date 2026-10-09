import SwiftUI
import Hanami

/// The article viewer's destinations, both the stored article and the
/// ephemeral one opened through `sakura://open`.
struct BrowserArticleDestinations: ViewModifier {

    @Environment(FeedManager.self) private var feedManager
    @Binding var path: NavigationPath

    func body(content: Content) -> some View {
        content
            .navigationDestination(for: Article.self) { article in
                articleDestination(article)
                    .environment(\.browserPathToken, .article(article.id))
            }
            .navigationDestination(for: EphemeralArticleDestination.self) { destination in
                ArticleDestinationView(
                    article: destination.article,
                    overrideMode: destination.mode,
                    overrideTextMode: destination.textMode
                )
                .browserNavigationEnvironment(path: $path)
                .browserPage(
                    title: destination.article.title,
                    subtitle: URL(string: destination.article.url)?.host,
                    symbolName: "doc.text"
                )
                .environment(\.browserPathToken, .ephemeralArticle(url: destination.article.url))
            }
    }

    /// An article that came from a feed names the feed, with the article's own
    /// title beneath it: the bar says where you are, and the page itself is
    /// already headed by the title.
    @ViewBuilder
    private func articleDestination(_ article: Article) -> some View {
        let feed = feedManager.feed(forArticle: article)
        ArticleDestinationView(article: article)
            .browserNavigationEnvironment(path: $path)
            .browserPage(
                title: feed?.title ?? article.displayTitle,
                subtitle: feed == nil
                    ? URL(string: article.url)?.host
                    : article.displayTitle,
                contentTitle: article.displayTitle,
                symbolName: "doc.text",
                feedID: feed?.id
            )
    }
}

extension View {
    func browserArticleDestinations(path: Binding<NavigationPath>) -> some View {
        modifier(BrowserArticleDestinations(path: path))
    }
}
