import SwiftUI
import Hanami

/// Wires the app's navigation closures into a tab's path, and in compact
/// layout hangs the chrome off every page's own `.bottomBar`.
struct BrowserNavigationEnvironment: ViewModifier {

    @Environment(FeedManager.self) private var feedManager
    @Environment(\.browserLayout) private var layout
    @Environment(\.browserOmniboxAction) private var openOmnibox
    @Environment(BrowserOmniboxModel.self) private var omnibox
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
            // No top bar in the browser: the page's own chrome lives in the
            // bottom bar instead.
            .toolbarVisibility(layout == .compact ? .hidden : .automatic, for: .navigationBar)
            .browserPopGestureEnabled(store: store)
            .toolbar {
                if layout == .compact {
                    BrowserBottomToolbar(
                        store: store,
                        feedManager: feedManager,
                        favourites: favourites,
                        omnibox: omnibox,
                        addressWidth: addressWidth,
                        onOpenOmnibox: { openOmnibox?() }
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
