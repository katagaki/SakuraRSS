import SwiftUI

/// A full-screen tab switcher behind the tab stack, with the stack zooming
/// down onto the selected tab's card while the switcher is shown. Cards
/// report where they sit with `tabCardFrame(id:in:)`.
public struct TabZoomContainer<Root: TabRoot, Identity: TabPageIdentity, Switcher: View, Page: View>: View {

    public static var coordinateSpaceName: String { TabZoomCoordinateSpace.name }

    private let store: TabNavigationStore<Root, Identity>
    private let cardCornerRadius: CGFloat
    private let switcher: Switcher
    private let page: (CGFloat) -> Page

    /// `page` is handed the container's width.
    public init(
        store: TabNavigationStore<Root, Identity>,
        cardCornerRadius: CGFloat,
        @ViewBuilder switcher: () -> Switcher,
        @ViewBuilder page: @escaping (CGFloat) -> Page
    ) {
        self.store = store
        self.cardCornerRadius = cardCornerRadius
        self.switcher = switcher()
        self.page = page
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Kept opaque rather than hidden: a transparent subtree is not
                // laid out, so the cards never report the frames the page
                // collapses onto.
                switcher
                    .allowsHitTesting(store.isShowingTabSwitcher)
                    .accessibilityHidden(!store.isShowingTabSwitcher)

                page(proxy.size.width)
                    .scaleEffect(pageScale(in: proxy.size), anchor: .topLeading)
                    .offset(pageOffset)
                    .clipShape(pageClipShape(in: proxy.size))
                    .animation(store.configuration.switcherAnimation, value: store.isPageCollapsed)
                    // No cross-fade: the swap happens where page and
                    // snapshot are pixel for pixel the same.
                    .opacity(store.isPageSwappedForSnapshot ? 0 : 1)
                    // Keyed on the unanimated flag: SwiftUI picks which
                    // toolbar to show from what is interactive, so the
                    // animated one swaps the bar mid-transition.
                    .allowsHitTesting(!store.isShowingTabSwitcher)
                    .accessibilityHidden(store.isShowingTabSwitcher)
            }
            .coordinateSpace(name: TabZoomCoordinateSpace.name)
        }
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
    private func pageClipShape(in size: CGSize) -> CollapsingPageClipShape {
        let screen = CGRect(
            origin: .zero,
            size: CGSize(width: size.width, height: max(size.height, DisplayMetrics.windowHeight))
        )
        return CollapsingPageClipShape(
            progress: store.isPageCollapsed ? 1 : 0,
            expanded: screen,
            collapsed: store.collapseTarget ?? screen,
            expandedRadius: DisplayMetrics.displayCornerRadius,
            collapsedRadius: cardCornerRadius
        )
    }
}

enum TabZoomCoordinateSpace {
    static let name = "EnhancedNavigation.TabZoom"
}

public extension View {
    /// Reports the rect the page collapses onto, before the switcher is ever
    /// shown.
    func tabCardFrame<Root, Identity>(
        id: UUID,
        in store: TabNavigationStore<Root, Identity>
    ) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear
                    .onChange(
                        of: proxy.frame(in: .named(TabZoomCoordinateSpace.name)),
                        initial: true
                    ) { _, frame in
                        store.setCardFrame(frame, for: id)
                    }
            }
        }
    }
}
