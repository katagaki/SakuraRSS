import SwiftUI
import Hanami

/// The destinations a feed list pushes: a feed, one of Home's sections, and a
/// list.
struct BrowserFeedDestinations: ViewModifier {

    @Binding var path: NavigationPath

    func body(content: Content) -> some View {
        content
            .navigationDestination(for: Feed.self) { feed in
                FeedArticlesView(feed: feed)
                    .browserNavigationEnvironment(path: $path)
                    .browserPage(
                        title: feed.title,
                        subtitle: feed.domain,
                        symbolName: "dot.radiowaves.up.forward",
                        feedID: feed.id
                    )
                    .browserRefreshScope("feed.\(feed.id)")
                    .environment(\.browserPathToken, .feed(feed.id))
            }
            .navigationDestination(for: FeedSection.self) { section in
                FeedSectionPage(section: section)
                    .browserNavigationEnvironment(path: $path)
                    .browserPage(
                        title: section.localizedTitle,
                        symbolName: section.browserSymbolName,
                        feedSection: section
                    )
                    .browserRefreshScope("section.\(section.rawValue)")
                    .environment(\.browserPathToken, .feedSection(section.rawValue))
            }
            .navigationDestination(for: FeedList.self) { list in
                ListArticlesView(list: list)
                    .browserNavigationEnvironment(path: $path)
                    .browserPage(title: list.name, symbolName: list.icon)
                    .browserRefreshScope("list.\(list.id)")
                    .environment(\.browserPathToken, .list(list.id))
            }
    }
}

extension View {
    func browserFeedDestinations(path: Binding<NavigationPath>) -> some View {
        modifier(BrowserFeedDestinations(path: path))
    }
}
