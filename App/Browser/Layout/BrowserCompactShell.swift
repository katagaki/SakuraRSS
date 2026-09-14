import SwiftUI
import Hanami

/// iPhone chrome. Each page carries its own `.bottomBar`, so this shell only
/// owns the tab stack, the tab switcher, and the measurement the address item
/// needs to span the bar.
struct BrowserCompactShell: View {

    @Environment(BrowserTabStore.self) private var store
    @Environment(BrowserFavourites.self) private var favourites
    @State private var containerWidth: CGFloat = 0

    var body: some View {
        // The page stays mounted and is transformed rather than swapped out:
        // tearing the tab stack down mid-animation rebuilds every live
        // navigation stack, which is what made the transition stutter.
        ZStack {
            if store.isShowingTabSwitcher {
                BrowserTabSwitcher()
                    .environment(store)
                    .environment(favourites)
                    .transition(.opacity)
            }

            // Scale and fade are animated apart so the page stays opaque while
            // it shrinks and only dissolves at the end. Fading both together
            // hides the page before its scale has read as movement.
            tabStack
                .scaleEffect(store.isShowingTabSwitcher ? 0.82 : 1)
                .animation(BrowserTabSwitcher.transitionAnimation, value: store.isShowingTabSwitcher)
                .opacity(store.isShowingTabSwitcher ? 0 : 1)
                .animation(pageFadeAnimation, value: store.isShowingTabSwitcher)
                .allowsHitTesting(!store.isShowingTabSwitcher)
                .accessibilityHidden(store.isShowingTabSwitcher)
        }
    }

    /// Leaving, the page holds its opacity so the shrink reads before it
    /// dissolves. Returning, it has to be visible immediately or it pops in
    /// after the grid has already gone.
    private var pageFadeAnimation: Animation {
        store.isShowingTabSwitcher
            ? .easeIn(duration: 0.16).delay(0.16)
            : .easeOut(duration: 0.18)
    }

    private var tabStack: some View {
        BrowserTabStack()
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: BrowserAddressWidthPreferenceKey.self,
                        value: proxy.size.width
                    )
                }
            }
            .onPreferenceChange(BrowserAddressWidthPreferenceKey.self) { width in
                containerWidth = width
            }
            .environment(\.isBrowserChromeActive, true)
            .environment(
                \.browserAddressWidth,
                BrowserAddressMetrics.addressWidth(forContainerWidth: containerWidth)
            )
    }
}
