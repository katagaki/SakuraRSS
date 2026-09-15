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
    let onOpenBookmarks: () -> Void
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

    private var browsingItems: some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            // With no top bar, Back lives here, and Bookmarks takes its
            // place while the tab sits at its root.
            if store.displayedCanGoBack {
                Button {
                    store.goBack()
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .accessibilityLabel(String(localized: "AddressBar.Back", table: "Browser"))
                .contextMenu {
                    ForEach(store.backHistory, id: \.depth) { entry in
                        Button {
                            store.popTo(depth: entry.depth)
                        } label: {
                            Label(entry.identity.title, systemImage: entry.identity.symbolName)
                        }
                    }
                }
            } else {
                Button(action: onOpenBookmarks) {
                    Image(systemName: "bookmark")
                }
                .accessibilityLabel(String(localized: "Location.Bookmarks", table: "Browser"))
            }

            Spacer()

            BrowserAddressItem(
                store: store,
                favourites: favourites,
                width: addressWidth,
                onOpenOmnibox: onOpenOmnibox
            )

            Spacer()

            Button {
                store.showTabSwitcher()
            } label: {
                BrowserTabCountLabel(count: store.tabs.count)
            }
            .accessibilityLabel(String(localized: "Tabs.Title", table: "Browser"))
        }
    }
}
