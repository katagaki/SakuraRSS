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
            .environment(
                \.browserAddressWidth,
                BrowserAddressMetrics.addressWidth(forContainerWidth: containerWidth)
            )
            .fullScreenCover(isPresented: tabSwitcherBinding) {
                BrowserTabSwitcher()
                    .environment(store)
                    .environment(favourites)
            }
    }

    private var tabSwitcherBinding: Binding<Bool> {
        Binding(
            get: { store.isShowingTabSwitcher },
            set: { store.isShowingTabSwitcher = $0 }
        )
    }
}
