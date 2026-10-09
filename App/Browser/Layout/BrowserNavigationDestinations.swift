import SwiftUI
import Hanami

/// Registers the destinations a tab is parked on or pushes from a list.
/// Applied once per tab, on the stack's root.
struct BrowserNavigationDestinations: ViewModifier {

    @Binding var path: NavigationPath

    func body(content: Content) -> some View {
        content
            .navigationDestination(for: BrowserLocation.self) { location in
                BrowserRootContentView(location: location)
                    .browserNavigationEnvironment(path: $path)
                    .environment(\.browserPathToken, .location(location.persistenceToken))
            }
            .navigationDestination(for: BrowserBookmarksDestination.self) { _ in
                BrowserBookmarksPage()
                    .browserNavigationEnvironment(path: $path)
                    .browserPage(
                        title: String(localized: "Location.Bookmarks", table: "Browser"),
                        symbolName: "bookmark"
                    )
                    .environment(\.browserPathToken, .bookmarks)
            }
            .navigationDestination(for: EntityDestination.self) { destination in
                EntityArticlesView(destination: destination)
                    .browserNavigationEnvironment(path: $path)
                    .browserPage(title: destination.name, symbolName: "tag")
                    .environment(
                        \.browserPathToken,
                        .entity(name: destination.name, types: destination.types)
                    )
            }
            .navigationDestination(for: SummaryHeadlineDestination.self) { destination in
                SummaryHeadlinesArticlesView(destination: destination)
                    .browserNavigationEnvironment(path: $path)
                    .browserPage(
                        title: String(localized: "Location.Headline", table: "Browser"),
                        symbolName: "sparkles"
                    )
                    .environment(
                        \.browserPathToken,
                        .headline(title: destination.title, articleIDs: destination.articleIDs)
                    )
            }
            .browserFeedDestinations(path: $path)
            .browserArticleDestinations(path: $path)
    }
}

extension View {
    func browserNavigationDestinations(path: Binding<NavigationPath>) -> some View {
        modifier(BrowserNavigationDestinations(path: path))
    }
}
