import SwiftUI
import Hanami

/// iPhone chrome. Each page carries its own `.bottomBar`, so this shell only
/// owns the tab stack, the tab switcher, and the geometry the address item and
/// the tab transition need.
struct BrowserCompactShell: View {

    @Environment(BrowserTabStore.self) private var store
    @Environment(BrowserFavourites.self) private var favourites

    var body: some View {
        // One reader spanning the safe areas gives the page's true bounds, and
        // the cards report into the same space, so the collapse is exact.
        GeometryReader { proxy in
            // The switcher stays mounted: it supplies the card frame the very
            // first time the transition runs, and its background fills the
            // screen so the safe areas never flash empty.
            ZStack {
                // Not hidden with opacity: a transparent subtree is not laid
                // out, so the cards never reported their frames and the page
                // had no target to collapse toward until after the flip. The
                // opaque page covers the grid instead.
                BrowserTabSwitcher()
                    .environment(store)
                    .environment(favourites)
                    .allowsHitTesting(store.isShowingTabSwitcher)
                    .accessibilityHidden(!store.isShowingTabSwitcher)

                // Scale and fade are animated apart so the page stays opaque
                // while it collapses and only dissolves once it has landed.
                tabStack(width: proxy.size.width)
                    .scaleEffect(pageScale(in: proxy.size), anchor: .topLeading)
                    .offset(pageOffset(in: proxy.size))
                    .clipShape(
                        BrowserPageClipShape(
                            rect: pageClipRect(in: proxy.size),
                            cornerRadius: pageCornerRadius
                        )
                    )
                    .animation(BrowserTabSwitcher.transitionAnimation, value: store.isPageCollapsed)
                    .opacity(store.isPageCollapsed ? 0 : 1)
                    .animation(pageFadeAnimation, value: store.isPageCollapsed)
                    // Keyed on the unanimated flag: SwiftUI picks whose
                    // toolbar to show from which view is interactive, so
                    // tying this to the animated state swapped the bottom
                    // bar partway through the transition.
                    .allowsHitTesting(!store.isShowingTabSwitcher)
                    .accessibilityHidden(store.isShowingTabSwitcher)
            }
            .coordinateSpace(name: BrowserTabZoom.coordinateSpace)
        }
        .ignoresSafeArea()
    }

    /// The page is only swapped for the snapshot at the one moment they are
    /// the same size: the very end of the collapse, and the very start of the
    /// growth. Dissolving anywhere in between puts two copies of the same page
    /// at different scales on top of each other, which reads as a snap.
    private var pageFadeAnimation: Animation {
        let duration = BrowserTabSwitcher.transitionDuration
        return store.isPageCollapsed
            ? .easeIn(duration: duration * 0.08).delay(duration * 0.92)
            : .easeOut(duration: duration * 0.04)
    }

    private var selectedCardFrame: CGRect? {
        guard store.isPageCollapsed else { return nil }
        // Prefer the snapshot's own rect; fall back to the whole card.
        return store.previewFrames[store.selectedTabID] ?? store.cardFrames[store.selectedTabID]
    }

    /// Each axis scales independently so the page lands on the card's exact
    /// rect; keeping it proportional leaves the page hanging below the card,
    /// because a page is far taller than a card is.
    /// One uniform scale, taken from the width. The card's snapshot is a top
    /// crop at that same scale, so scaling each axis to fit the card instead
    /// squashes the live page against it.
    private func pageScale(in size: CGSize) -> CGFloat {
        guard let card = selectedCardFrame, size.width > 0 else { return 1 }
        return card.width / size.width
    }

    /// Anchored so the page's safe area top lands on the card's top edge; the
    /// overflow below is cropped rather than squeezed.
    private func pageOffset(in size: CGSize) -> CGSize {
        guard let card = selectedCardFrame else { return .zero }
        let scale = pageScale(in: size)
        return CGSize(
            width: card.minX,
            height: card.minY - BrowserDeviceMetrics.safeAreaInsets.top * scale
        )
    }

    /// The card's rect while collapsed, the whole screen otherwise.
    private func pageClipRect(in size: CGSize) -> CGRect {
        guard let card = selectedCardFrame else {
            return CGRect(origin: .zero, size: size)
        }
        return card
    }

    /// Applied after the scale now, so it is the card's radius directly.
    private var pageCornerRadius: CGFloat {
        store.isPageCollapsed
            ? BrowserTabCard.cornerRadius
            : BrowserDeviceMetrics.displayCornerRadius
    }

    private func tabStack(width: CGFloat) -> some View {
        BrowserTabStack()
            // The page is what gets scaled into the card, so it has to draw
            // edge to edge: otherwise the snapshot carries blank status bar and
            // home indicator bands into the card with it.
            .ignoresSafeArea()
            .environment(\.isBrowserChromeActive, true)
            .environment(
                \.browserAddressWidth,
                BrowserAddressMetrics.addressWidth(forContainerWidth: width)
            )
    }
}
