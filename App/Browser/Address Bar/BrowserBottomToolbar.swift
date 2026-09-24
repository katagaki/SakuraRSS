import SwiftUI
import Hanami

/// The compact chrome, as a real `.bottomBar` so it gets the system's glass,
/// safe area and scroll behaviour.
struct BrowserBottomToolbar: ToolbarContent {

    let store: BrowserTabStore
    let feedManager: FeedManager
    let favourites: BrowserFavourites
    let omnibox: BrowserOmniboxModel
    /// Measured by the shell: toolbar items cannot stretch on their own.
    let addressWidth: CGFloat
    let onOpenOmnibox: () -> Void

    // The editing field is not a toolbar item: a `.bottomBar` does not lift
    // itself above the keyboard, so it would edit from under it.
    @ToolbarContentBuilder
    var body: some ToolbarContent {
        if !omnibox.isActive {
            browsingItems
        }
    }

    @ToolbarContentBuilder
    private var browsingItems: some ToolbarContent {
        // With no top bar, Back lives here. It stays put at a tab's root,
        // disabled, so the address item doesn't jump as pages are pushed.
        ToolbarItem(placement: .bottomBar) {
            // A `Menu` with a primary action keeps tap = go back while
            // long press opens the history on the button's own glass;
            // `.contextMenu` would detach into its own dark sheet.
            Menu {
                ForEach(store.backHistory, id: \.depth) { entry in
                    Button {
                        store.popTo(depth: entry.depth)
                    } label: {
                        Label(entry.identity.title, systemImage: entry.identity.symbolName)
                    }
                }
            } label: {
                Label(
                    String(localized: "AddressBar.Back", table: "Browser"),
                    systemImage: "chevron.backward"
                )
            } primaryAction: {
                store.goBack()
            }
            .disabled(!store.displayedCanGoBack)
        }

        #if !os(visionOS)
        ToolbarSpacer(.flexible, placement: .bottomBar)
        #endif

        ToolbarItem(placement: .bottomBar) {
            BrowserAddressItem(
                store: store,
                favourites: favourites,
                width: addressWidth,
                onOpenOmnibox: onOpenOmnibox
            )
        }

        #if !os(visionOS)
        ToolbarSpacer(.flexible, placement: .bottomBar)
        #endif

        ToolbarItem(placement: .bottomBar) {
            Button {
                store.showTabSwitcher()
            } label: {
                BrowserTabCountLabel(count: store.tabs.count)
            }
            .accessibilityLabel(String(localized: "Tabs.Title", table: "Browser"))
        }
    }
}
