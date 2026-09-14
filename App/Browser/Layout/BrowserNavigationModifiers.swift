import SwiftUI
import Hanami

/// Wires the app's navigation environment closures into a browser tab's path,
/// and — in compact layout — hangs the browser chrome off every page's own
/// `.bottomBar` so the system owns its glass, safe area and scroll behaviour.
struct BrowserNavigationEnvironment: ViewModifier {

    @Environment(FeedManager.self) private var feedManager
    @Environment(\.browserLayout) private var layout
    @Environment(\.browserOmniboxAction) private var openOmnibox
    @Environment(\.browserAddressWidth) private var addressWidth
    @Environment(BrowserTabStore.self) private var store
    @Environment(BrowserFavourites.self) private var favourites
    @Binding var path: NavigationPath
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        content
            .environment(\.zoomNamespace, namespace)
            .environment(\.navigateToFeed) { path.append($0) }
            .environment(\.navigateToEphemeralArticle) { path.append($0) }
            .environment(\.navigateToSummaryHeadline) { path.append($0) }
            .toolbar {
                if layout == .compact {
                    BrowserBottomToolbar(
                        store: store,
                        feedManager: feedManager,
                        favourites: favourites,
                        onOpenOmnibox: { openOmnibox?() },
                        addressWidth: addressWidth
                    )
                }
            }
    }
}

extension View {
    func browserNavigationEnvironment(
        path: Binding<NavigationPath>,
        namespace: Namespace.ID
    ) -> some View {
        modifier(BrowserNavigationEnvironment(path: path, namespace: namespace))
    }
}
