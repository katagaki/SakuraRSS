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
                    .offset(pageOffset)
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

    /// Leaving, the page holds its opacity so the collapse reads before it
    /// dissolves. Returning, it goes opaque almost at once: a page that fades
    /// in while it grows lets the grid show through it, and the card's content
    /// and the page's are then both visible at the same spot.
    private var pageFadeAnimation: Animation {
        store.isShowingTabSwitcher
            ? .easeIn(duration: 0.14).delay(0.20)
            : .easeOut(duration: 0.08)
    }

    private var selectedCardFrame: CGRect? {
        guard store.isShowingTabSwitcher else { return nil }
        return store.cardFrames[store.selectedTabID]
    }

    /// Each axis scales independently so the page lands on the card's exact
    /// rect; keeping it proportional leaves the page hanging below the card,
    /// because a page is far taller than a card is.
    private func pageScale(in size: CGSize) -> CGSize {
        guard let card = selectedCardFrame, size.width > 0, size.height > 0 else {
            return CGSize(width: 1, height: 1)
        }
        return CGSize(width: card.width / size.width, height: card.height / size.height)
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

    /// Anchored top-leading, so landing on the card is just its origin.
    private var pageOffset: CGSize {
        guard let card = selectedCardFrame else { return .zero }
        return CGSize(width: card.minX, height: card.minY)
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
