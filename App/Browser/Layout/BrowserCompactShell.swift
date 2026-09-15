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
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: pageCornerRadius(in: proxy.size),
                            style: .continuous
                        )
                    )
                    .scaleEffect(pageScale(in: proxy.size), anchor: .topLeading)
                    .offset(pageOffset(in: proxy.size))
                    .animation(BrowserTabSwitcher.transitionAnimation, value: store.isShowingTabSwitcher)
                    .opacity(store.isShowingTabSwitcher ? 0 : 1)
                    .animation(pageFadeAnimation, value: store.isShowingTabSwitcher)
                    .allowsHitTesting(!store.isShowingTabSwitcher)
                    .accessibilityHidden(store.isShowingTabSwitcher)
            }
            .coordinateSpace(name: BrowserTabZoom.coordinateSpace)
        }
        .ignoresSafeArea()
    }

    /// Tied to the scale rather than set independently, so the swap always
    /// lands where the page and the card's snapshot are the same size. Fading
    /// earlier cross-dissolves a half-shrunk page against a full-size snapshot,
    /// which reads as a snap.
    private var pageFadeAnimation: Animation {
        let duration = BrowserTabSwitcher.transitionDuration
        return store.isShowingTabSwitcher
            ? .easeIn(duration: duration * 0.08).delay(duration * 0.92)
            : .easeOut(duration: duration * 0.25)
    }

    private var selectedCardFrame: CGRect? {
        guard store.isShowingTabSwitcher else { return nil }
        // Prefer the snapshot's own rect; fall back to the whole card.
        return store.previewFrames[store.selectedTabID] ?? store.cardFrames[store.selectedTabID]
    }

    /// Each axis scales independently so the page lands on the card's exact
    /// rect; keeping it proportional leaves the page hanging below the card,
    /// because a page is far taller than a card is.
    /// Scaled so the page's *safe area* lands on the card, because that is the
    /// region the card's snapshot covers. Mapping the full frame instead leaves
    /// the live page and the snapshot offset from each other, and they ghost
    /// against one another as one fades into the other.
    private func pageScale(in size: CGSize) -> CGSize {
        guard let card = selectedCardFrame, size.width > 0 else {
            return CGSize(width: 1, height: 1)
        }
        let content = size.height - BrowserDeviceMetrics.safeAreaInsets.top
            - BrowserDeviceMetrics.safeAreaInsets.bottom
        guard content > 0 else { return CGSize(width: 1, height: 1) }
        return CGSize(width: card.width / size.width, height: card.height / content)
    }

    /// Anchored top-leading, so the page's safe area top lands on the card's.
    private func pageOffset(in size: CGSize) -> CGSize {
        guard let card = selectedCardFrame else { return .zero }
        let scaleY = pageScale(in: size).height
        return CGSize(
            width: card.minX,
            height: card.minY - BrowserDeviceMetrics.safeAreaInsets.top * scaleY
        )
    }

    /// Clipping happens before the scale, so the radius has to be divided by
    /// the scale to land on the card's actual corner radius.
    private func pageCornerRadius(in size: CGSize) -> CGFloat {
        let scale = pageScale(in: size).width
        guard store.isShowingTabSwitcher, scale > 0 else {
            return BrowserDeviceMetrics.displayCornerRadius
        }
        return BrowserTabCard.cornerRadius / scale
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
