import SwiftUI
import Hanami

/// iPhone chrome. Each page carries its own `.bottomBar`, so this shell only
/// owns the tab stack, the tab switcher, and the measurements the address item
/// and the tab transition need.
struct BrowserCompactShell: View {

    @Environment(BrowserTabStore.self) private var store
    @Environment(BrowserFavourites.self) private var favourites
    @State private var pageFrame: CGRect = .zero
    @State private var cardFrames: [UUID: CGRect] = [:]

    var body: some View {
        // The switcher stays mounted: it supplies the card frame the page
        // collapses into, and its background fills the screen so the safe areas
        // never flash empty as the page shrinks away from the edges.
        ZStack {
            BrowserTabSwitcher()
                .environment(store)
                .environment(favourites)
                .opacity(store.isShowingTabSwitcher ? 1 : 0)
                .allowsHitTesting(store.isShowingTabSwitcher)
                .accessibilityHidden(!store.isShowingTabSwitcher)
                .animation(BrowserTabSwitcher.transitionAnimation, value: store.isShowingTabSwitcher)

            // Scale and fade are animated apart so the page stays opaque while
            // it collapses and only dissolves once it has reached the card.
            tabStack
                .scaleEffect(pageScale, anchor: .center)
                .offset(pageOffset)
                .animation(BrowserTabSwitcher.transitionAnimation, value: store.isShowingTabSwitcher)
                .opacity(store.isShowingTabSwitcher ? 0 : 1)
                .animation(pageFadeAnimation, value: store.isShowingTabSwitcher)
                .allowsHitTesting(!store.isShowingTabSwitcher)
                .accessibilityHidden(store.isShowingTabSwitcher)
        }
        .coordinateSpace(name: BrowserTabZoom.coordinateSpace)
        .onPreferenceChange(BrowserTabCardFramePreferenceKey.self) { frames in
            cardFrames = frames
        }
    }

    /// Leaving, the page holds its opacity so the collapse reads before it
    /// dissolves. Returning, it has to be visible immediately or it pops in
    /// after the grid has already gone.
    private var pageFadeAnimation: Animation {
        store.isShowingTabSwitcher
            ? .easeIn(duration: 0.14).delay(0.20)
            : .easeOut(duration: 0.18)
    }

    private var selectedCardFrame: CGRect? {
        guard pageFrame.width > 0, pageFrame.height > 0 else { return nil }
        return cardFrames[store.selectedTabID]
    }

    private var pageScale: CGFloat {
        guard store.isShowingTabSwitcher, let card = selectedCardFrame else { return 1 }
        return card.width / pageFrame.width
    }

    /// Lands the page's top edge on the card's, the way Safari's card shows the
    /// top of the page. Centring it instead leaves the page hanging well below
    /// the card, because a page is far taller than a card is.
    private var pageOffset: CGSize {
        guard store.isShowingTabSwitcher, let card = selectedCardFrame else { return .zero }
        let scaledTop = pageFrame.midY - pageFrame.height * pageScale / 2
        return CGSize(
            width: card.midX - pageFrame.midX,
            height: card.minY - scaledTop
        )
    }

    private var tabStack: some View {
        BrowserTabStack()
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: BrowserContainerFramePreferenceKey.self,
                        value: proxy.frame(in: .named(BrowserTabZoom.coordinateSpace))
                    )
                }
            }
            .onPreferenceChange(BrowserContainerFramePreferenceKey.self) { frame in
                pageFrame = frame
            }
            .environment(\.isBrowserChromeActive, true)
            .environment(
                \.browserAddressWidth,
                BrowserAddressMetrics.addressWidth(forContainerWidth: pageFrame.width)
            )
    }
}
