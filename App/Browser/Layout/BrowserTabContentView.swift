import SwiftUI
import Hanami

/// One tab's navigation stack. Kept alive only while the tab is recent; an
/// evicted tab keeps its `NavigationPath` in the store and rebuilds from it.
struct BrowserTabContentView: View {

    @Environment(FeedManager.self) private var feedManager
    let store: BrowserTabStore
    let tabID: UUID
    @Namespace private var cardZoom

    private var location: BrowserLocation {
        store.tabs.first { $0.id == tabID }?.location ?? .startPage
    }

    var body: some View {
        let path = store.pathBinding(for: tabID)
        NavigationStack(path: path) {
            BrowserRootContentView(location: location)
                .browserNavigationEnvironment(path: path, namespace: cardZoom)
                .browserNavigationDestinations(path: path, namespace: cardZoom)
        }
        .environment(\.browserTabID, tabID)
        .environment(\.browserPageReporter) { identity in
            store.setPageIdentity(identity, for: tabID)
        }
        .environment(\.browserPageSlotReporter) { report, token in
            store.setSlot(report, token: token, for: tabID)
        }
        .compatibleSoftScrollEdgeEffectStyle()
        // Last session's stack, rebuilt the first time the tab is mounted.
        .onAppear { store.restorePathIfNeeded(for: tabID, in: feedManager) }
    }
}
