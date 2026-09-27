import EnhancedNavigation
import SwiftUI
import Hanami

/// iPhone chrome: the tab stack, the switcher, and the geometry the collapse
/// transition runs on.
struct BrowserCompactShell: View {

    @Environment(BrowserTabStore.self) private var store
    @Environment(BrowserFavourites.self) private var favourites

    var body: some View {
        TabZoomContainer(store: store, cardCornerRadius: TabSwitcherCardMetrics.cornerRadius) {
            BrowserTabSwitcher()
                .environment(store)
                .environment(favourites)
        } page: { _ in
            tabStack
        }
        // Container only: swallowing the keyboard region too leaves the
        // bottom bar, and so the address field, under the keyboard.
        .ignoresSafeArea(.container)
        // One per shell, not one per page: mounted per page, the overlay and
        // its focused field can end up on screen twice. Outside the safe area
        // override, or with the keyboard down the editing bar rests against
        // the screen's edge instead of above the home indicator.
        .overlay {
            BrowserOmniboxOverlay()
        }
    }

    private var tabStack: some View {
        BrowserTabStack()
            // Edge to edge, or the snapshot carries blank status bar and home
            // indicator bands into the card.
            .ignoresSafeArea(.container)
            .environment(\.isBrowserChromeActive, true)
    }
}
