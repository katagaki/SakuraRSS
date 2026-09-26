import EnhancedNavigation
import SwiftUI
import Hanami

/// One tab's navigation stack. Kept alive only while the tab is recent; an
/// evicted tab keeps its `NavigationPath` in the store and rebuilds from it.
struct BrowserTabContentView: View {

    @Environment(FeedManager.self) private var feedManager
    @Environment(\.browserLayout) private var layout
    let store: BrowserTabStore
    let tabID: UUID
    /// Handed in rather than looked up: reading `store.tabs` here re-runs
    /// this body, and every page under it, whenever any tab changes.
    let location: BrowserLocation
    @State private var reporters: BrowserTabReporters
    @Namespace private var cardZoom

    init(store: BrowserTabStore, slots: BrowserPageSlots, tabID: UUID, location: BrowserLocation) {
        self.store = store
        self.tabID = tabID
        self.location = location
        _reporters = State(initialValue: BrowserTabReporters(store: store, slots: slots, tabID: tabID))
    }

    var body: some View {
        let path = store.pathBinding(for: tabID)
        NavigationStack(path: path) {
            BrowserRootContentView(location: location)
                .browserNavigationEnvironment(path: path, namespace: cardZoom)
                .browserNavigationDestinations(path: path, namespace: cardZoom)
        }
        .browserBottomBar(for: tabID, in: store, isEnabled: layout == .compact)
        .environment(\.browserTabID, tabID)
        .environment(\.browserPageReporter, reporters.page)
        .environment(\.browserOverlayPageReporter, reporters.overlayPage)
        .environment(\.browserPageSlotReporter, reporters.slot)
        .compatibleSoftScrollEdgeEffectStyle()
        // Last session's stack, rebuilt the first time the tab is mounted.
        .onAppear { store.restorePathIfNeeded(for: tabID, in: feedManager) }
    }
}
