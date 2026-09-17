import SwiftUI
import Hanami

/// iPhone chrome: the tab stack, the switcher, and the geometry the collapse
/// transition runs on.
struct BrowserCompactShell: View {

    @Environment(BrowserTabStore.self) private var store
    @Environment(BrowserFavourites.self) private var favourites

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Kept opaque rather than hidden: a transparent subtree is not
                // laid out, so the cards never report the frames the page
                // collapses onto.
                BrowserTabSwitcher()
                    .environment(store)
                    .environment(favourites)
                    .allowsHitTesting(store.isShowingTabSwitcher)
                    .accessibilityHidden(!store.isShowingTabSwitcher)

                tabStack(width: proxy.size.width)
                    .scaleEffect(pageScale(in: proxy.size), anchor: .topLeading)
                    .offset(pageOffset)
                    .clipShape(pageClipShape(in: proxy.size))
                    .animation(BrowserTabSwitcher.transitionAnimation, value: store.isPageCollapsed)
                    // No cross-fade: the swap happens where page and
                    // snapshot are pixel for pixel the same.
                    .opacity(store.isPageSwappedForSnapshot ? 0 : 1)
                    // Keyed on the unanimated flag: SwiftUI picks which
                    // toolbar to show from what is interactive, so the
                    // animated one swaps the bar mid-transition.
                    .allowsHitTesting(!store.isShowingTabSwitcher)
                    .accessibilityHidden(store.isShowingTabSwitcher)
            }
            .coordinateSpace(name: BrowserTabZoom.coordinateSpace)
        }
        .ignoresSafeArea(.container)
        .browserKeyboardInset()
    }

    private var selectedCardFrame: CGRect? {
        store.isPageCollapsed ? store.collapseTarget : nil
    }

    private func pageScale(in size: CGSize) -> CGFloat {
        guard let card = selectedCardFrame, size.width > 0 else { return 1 }
        return card.width / size.width
    }

    /// The page's origin is where the snapshot's crop starts, so the card's
    /// origin is the whole offset; correcting for the safe area double-counts
    /// it and lifts the page clear of the snapshot.
    private var pageOffset: CGSize {
        guard let card = selectedCardFrame else { return .zero }
        return CGSize(width: card.minX, height: card.minY)
    }

    /// Only `progress` animates, so the rects it interpolates between have to
    /// outlive the transition: hence the store's target rather than the
    /// nil-when-open `selectedCardFrame`.
    private func pageClipShape(in size: CGSize) -> BrowserPageClipShape {
        let screen = CGRect(
            origin: .zero,
            size: CGSize(width: size.width, height: max(size.height, BrowserDeviceMetrics.windowHeight))
        )
        return BrowserPageClipShape(
            progress: store.isPageCollapsed ? 1 : 0,
            expanded: screen,
            collapsed: store.collapseTarget ?? screen,
            expandedRadius: BrowserDeviceMetrics.displayCornerRadius,
            collapsedRadius: BrowserTabCard.cornerRadius
        )
    }

    private func tabStack(width: CGFloat) -> some View {
        BrowserTabStack()
            // Edge to edge, or the snapshot carries blank status bar and home
            // indicator bands into the card.
            .ignoresSafeArea(.container)
            .environment(\.isBrowserChromeActive, true)
    }
}
