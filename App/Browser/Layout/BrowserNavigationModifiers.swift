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
    @Environment(BrowserChromeMetrics.self) private var chromeMetrics
    @Environment(\.browserTabID) private var tabID
    @Environment(\.browserPathToken) private var pathToken
    @Binding var path: NavigationPath
    let namespace: Namespace.ID

    /// Every page of every mounted tab carries this modifier: ungated, the
    /// omnibox would mount a dimming overlay and a focused field per page.
    private var isDisplayedPage: Bool {
        tabID == store.selectedTabID
            && pathToken == store.selectedTab.pageIdentity?.pathToken
    }

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
            // What the bar claims out of the page, read off the page itself:
            // toolbar items cannot report the glass drawn around them.
            .background {
                if layout == .compact, isDisplayedPage, !omnibox.isActive {
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { chromeMetrics.barInset = proxy.safeAreaInsets.bottom }
                            .onChange(of: proxy.safeAreaInsets.bottom) {
                                chromeMetrics.barInset = proxy.safeAreaInsets.bottom
                            }
                    }
                }
            }
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
