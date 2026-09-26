import EnhancedNavigation
import SwiftUI

/// The compact chrome. One per tab, hung off its `NavigationStack` rather
/// than each page's `.bottomBar`, so it holds still while pages push and pop.
/// `tabBottomBar` puts it where the system bar would sit and keeps the soft
/// scroll edge effect under it.
struct BrowserBottomBar: View {

    @Environment(BrowserTabStore.self) private var store
    @Environment(BrowserPageSlots.self) private var slots
    @Environment(BrowserFavourites.self) private var favourites
    @Environment(BrowserOmniboxModel.self) private var omnibox
    @Environment(\.browserOmniboxAction) private var openOmnibox
    /// The tab this bar belongs to. The bar reads its own tab's state, not
    /// the selection's, so switching tabs leaves the other tabs' bars alone.
    let tabID: UUID

    var body: some View {
        CompatibleGlassEffectContainer(spacing: TabBottomBarMetrics.itemSpacing) {
            HStack(spacing: TabBottomBarMetrics.itemSpacing) {
                backButton
                BrowserAddressItem(
                    store: store,
                    slots: slots,
                    tabID: tabID,
                    favourites: favourites,
                    onOpenOmnibox: { openOmnibox?() }
                )
                .compatibleGlassEffect(in: .capsule, interactive: true)
                tabsButton
            }
        }
        .foregroundStyle(.primary)
        // What a `.bottomBar` gives its items' symbols.
        .imageScale(.large)
        // Hidden rather than removed while the omnibox edits in its place:
        // removing it would take its inset away and shift every page under it.
        .opacity(omnibox.isActive ? 0 : 1)
        .allowsHitTesting(!omnibox.isActive)
        .accessibilityHidden(omnibox.isActive)
    }

    /// With no top bar, Back lives here. It stays put at a tab's root,
    /// disabled, so the address item doesn't jump as pages are pushed.
    private var backButton: some View {
        let canGoBack = store.displayedCanGoBack(for: tabID)
        // A `Menu` with a primary action keeps tap = go back while long press
        // opens the history on the button's own glass; `.contextMenu` would
        // detach into its own dark sheet.
        return Menu {
            ForEach(store.backHistory(for: tabID), id: \.depth) { entry in
                Button {
                    store.popTo(depth: entry.depth)
                } label: {
                    Label(entry.identity.title, systemImage: entry.identity.symbolName)
                }
            }
        } label: {
            Image(systemName: "chevron.backward")
                .font(.system(size: 17, weight: .medium))
                // Set here, since the bar's own primary style would
                // otherwise keep the chevron from dimming when disabled.
                .foregroundStyle(canGoBack ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                .frame(width: TabBottomBarMetrics.itemHeight, height: TabBottomBarMetrics.itemHeight)
                .contentShape(.circle)
        } primaryAction: {
            store.goBack()
        }
        .compatibleGlassEffect(in: .circle, interactive: true)
        .disabled(!canGoBack)
        .accessibilityLabel(String(localized: "AddressBar.Back", table: "Browser"))
    }

    private var tabsButton: some View {
        Button {
            store.showTabSwitcher()
        } label: {
            BrowserTabCountLabel(count: store.tabs.count)
                .frame(width: TabBottomBarMetrics.itemHeight, height: TabBottomBarMetrics.itemHeight)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .compatibleGlassEffect(in: .circle, interactive: true)
        .accessibilityLabel(String(localized: "Tabs.Title", table: "Browser"))
    }
}

extension View {
    @ViewBuilder
    func browserBottomBar(for tabID: UUID, isEnabled: Bool) -> some View {
        if isEnabled {
            tabBottomBar {
                BrowserBottomBar(tabID: tabID)
            }
        } else {
            self
        }
    }
}
