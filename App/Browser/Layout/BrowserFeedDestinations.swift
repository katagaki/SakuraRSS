import SwiftUI
import Hanami

/// The destinations a feed list pushes: a feed, one of Home's sections, and a
/// list.
struct BrowserFeedDestinations: ViewModifier {

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
                    .environment(\.browserPathToken, .feed(feed.id))
            }
            .navigationDestination(for: FeedSection.self) { section in
                HomeSectionView(section: section)
                    .browserNavigationEnvironment(path: $path, namespace: namespace)
                    .browserPage(
                        title: section.localizedTitle,
                        symbolName: section.browserSymbolName
                    )
                    .environment(\.browserPathToken, .feedSection(section.rawValue))
            }
            .navigationDestination(for: FeedList.self) { list in
                ListArticlesView(list: list)
                    .browserNavigationEnvironment(path: $path, namespace: namespace)
                    .browserPage(title: list.name, symbolName: list.icon)
                    .environment(\.browserPathToken, .list(list.id))
            }
    }
}

extension View {
    func browserFeedDestinations(
        path: Binding<NavigationPath>,
        namespace: Namespace.ID
    ) -> some View {
        modifier(BrowserFeedDestinations(path: path, namespace: namespace))
    }
}
