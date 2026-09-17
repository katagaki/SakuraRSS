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
    let isDisplayedPage: Bool
    let onOpenOmnibox: () -> Void
    let onSubmitOmnibox: () -> Void

    var body: some ToolbarContent {
        if omnibox.isActive {
            editingItems
        } else {
            browsingItems
        }
    }

    @ToolbarContentBuilder
    private var editingItems: some ToolbarContent {
        // Separate items with a fixed spacer: a group shares one glass
        // capsule, and a flexible spacer splits them to opposite ends.
        ToolbarItem(placement: .bottomBar) {
            BrowserOmniboxField(
                model: omnibox,
                width: BrowserAddressMetrics.fieldWidth(forAddressWidth: addressWidth),
                focusesOnAppear: isDisplayedPage,
                onSubmit: onSubmitOmnibox
            )
        }

        #if !os(visionOS)
        ToolbarSpacer(.fixed, placement: .bottomBar)
        #endif

        ToolbarItem(placement: .bottomBar) {
            Button(role: .cancel) {
                withAnimation(BrowserOmniboxModel.transition) {
                    omnibox.deactivate()
                }
            }
        }
    }

    private var browsingAddressWidth: CGFloat {
        store.displayedCanGoBack
            ? addressWidth
            : addressWidth + BrowserAddressMetrics.leadingButtonWidth
    }

    @ToolbarContentBuilder
    private var browsingItems: some ToolbarContent {
        // With no top bar, Back lives here. At a tab's root there is nothing
        // to go back to, and the address item starts at the leading edge
        // rather than sitting behind an empty slot.
        if store.displayedCanGoBack {
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
                    Image(systemName: "chevron.backward")
                } primaryAction: {
                    store.goBack()
                }
                .accessibilityLabel(String(localized: "AddressBar.Back", table: "Browser"))
            }

            #if !os(visionOS)
            ToolbarSpacer(.flexible, placement: .bottomBar)
            #endif
        }

        ToolbarItem(placement: .bottomBar) {
            BrowserAddressItem(
                store: store,
                favourites: favourites,
                width: browsingAddressWidth,
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
