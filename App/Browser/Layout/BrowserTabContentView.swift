import SwiftUI
import Hanami

/// One tab's navigation stack. Kept alive only while the tab is recent; an
/// evicted tab keeps its `NavigationPath` in the store and rebuilds from it.
struct BrowserTabContentView: View {

    let store: BrowserTabStore
    let tabID: UUID
    @Namespace private var cardZoom

    /// Height of an inline navigation bar. SwiftUI does not report it as a
    /// safe area inset here, because the page scrolls under it.
    private static let navigationBarHeight: CGFloat = 44

    private var tab: BrowserTab? {
        store.tabs.first { $0.id == tabID }
    }

    private var location: BrowserLocation {
        tab?.location ?? .startPage
    }

    /// Only the start page hides its bar, and only while nothing is pushed on
    /// top of it.
    private var hidesNavigationBar: Bool {
        location.isStartPage && (tab?.path.isEmpty ?? true)
    }

    var body: some View {
        let path = store.pathBinding(for: tabID)
        NavigationStack(path: path) {
            BrowserRootContentView(location: location)
                .browserNavigationEnvironment(path: path, namespace: cardZoom)
                .browserNavigationDestinations(path: path, namespace: cardZoom)
                .background {
                    // Reports where the page's content starts, so a snapshot
                    // can crop the chrome above it away.
                    GeometryReader { proxy in
                        Color.clear
                            .onChange(of: contentTop(safeAreaTop: proxy.safeAreaInsets.top),
                                      initial: true) { _, top in
                                store.setContentTopInset(top, for: tabID)
                            }
                    }
                }
        }
        .environment(\.browserPageReporter) { identity in
            store.setPageIdentity(identity, for: tabID)
        }
        .compatibleSoftScrollEdgeEffectStyle()
    }

    private func contentTop(safeAreaTop: CGFloat) -> CGFloat {
        safeAreaTop + (hidesNavigationBar ? 0 : BrowserTabContentView.navigationBarHeight)
    }
}
