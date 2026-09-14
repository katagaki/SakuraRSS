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
        // Rendered in place rather than as a cover so the two can cross-fade.
        // Both sides transition with a scale transform rather than a matched
        // frame: animating the frame re-lays the page out on every tick.
        ZStack {
            if store.isShowingTabSwitcher {
                BrowserTabSwitcher()
                    .environment(store)
                    .environment(favourites)
                    .transition(.scale(scale: 1.08).combined(with: .opacity))
            } else {
                tabStack
                    .transition(.scale(scale: 0.88).combined(with: .opacity))
            }
        }
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
