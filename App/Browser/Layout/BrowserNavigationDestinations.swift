import SwiftUI
import Hanami

/// Registers the destinations a tab is parked on or pushes from a list.
/// Applied once per tab, on the stack's root.
struct BrowserNavigationDestinations: ViewModifier {

    @Binding var path: NavigationPath
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        content
            .navigationDestination(for: BrowserLocation.self) { location in
                BrowserRootContentView(location: location)
                    .browserNavigationEnvironment(path: $path, namespace: namespace)
                    .environment(\.browserPathToken, .location(location.persistenceToken))
            }
            .navigationDestination(for: BrowserBookmarksDestination.self) { _ in
                BrowserBookmarksPage()
                    .browserNavigationEnvironment(path: $path, namespace: namespace)
                    .browserPage(
                        title: String(localized: "Location.Bookmarks", table: "Browser"),
                        symbolName: "bookmark"
                    )
                    .environment(\.browserPathToken, .bookmarks)
            }
            .navigationDestination(for: Feed.self) { feed in
                FeedArticlesView(feed: feed)
                    .browserNavigationEnvironment(path: $path, namespace: namespace)
                    .browserPage(
                        title: feed.title,
                        subtitle: feed.domain,
                        symbolName: "dot.radiowaves.up.forward",
                        feedID: feed.id
                    )
                    .environment(\.browserPathToken, .feed(feed.id))
            }
            .navigationDestination(for: EntityDestination.self) { destination in
                EntityArticlesView(destination: destination)
                    .browserNavigationEnvironment(path: $path, namespace: namespace)
                    .browserPage(title: destination.name, symbolName: "tag")
                    .environment(
                        \.browserPathToken,
                        .entity(name: destination.name, types: destination.types)
                    )
            }
            .navigationDestination(for: SummaryHeadlineDestination.self) { destination in
                SummaryHeadlinesArticlesView(destination: destination)
                    .browserNavigationEnvironment(path: $path, namespace: namespace)
                    .browserPage(
                        title: String(localized: "Location.Headline", table: "Browser"),
                        symbolName: "sparkles"
                    )
                    .zoomTransition(sourceID: destination.zoomTransitionID, in: namespace)
                    .environment(
                        \.browserPathToken,
                        .headline(title: destination.title, articleIDs: destination.articleIDs)
                    )
            }
            .browserArticleDestinations(path: $path, namespace: namespace)
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
