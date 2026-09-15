import SwiftUI
import Hanami

/// The compact chrome, as a real `.bottomBar` toolbar rather than a floating
/// overlay, so it gets the system's glass, safe area and scroll behaviour.
/// While editing it morphs into the address field and a Cancel button, the way
/// Safari's bottom bar does.
struct BrowserBottomToolbar: ToolbarContent {

    let store: BrowserTabStore
    let feedManager: FeedManager
    let favourites: BrowserFavourites
    let omnibox: BrowserOmniboxModel
    /// Measured by the shell: toolbar items size to their content, so neither
    /// the address item nor the field can stretch on its own.
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
        // Separate items with a fixed spacer between them: a group would give
        // the field and the cancel button one shared glass capsule, and a
        // flexible spacer would push them to opposite ends of the bar.
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
                omnibox.deactivate()
            }
        }
    }

    private var browsingItems: some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            // Bookmarks while the tab sits at its root; Back once it has
            // somewhere to go back to. With no top bar there is nowhere else to
            // put Back.
            if store.selectedTab.canGoBack {
                Button {
                    store.goBack()
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .accessibilityLabel(String(localized: "AddressBar.Back", table: "Browser"))
            } else {
                Button(action: onOpenBookmarks) {
                    Image(systemName: "bookmark")
                }
                .accessibilityLabel(String(localized: "Location.Bookmarks", table: "Browser"))
            }

            Spacer()

            Button(action: onOpenOmnibox) {
                BrowserLocationLabel(
                    description: BrowserLocationDescription.describe(
                        store.selectedTab,
                        feedManager: feedManager
                    ),
                    iconSize: 24,
                    titleFont: .subheadline,
                    showsSubtitle: true
                )
                .padding(.leading, 8)
                .frame(
                    width: addressWidth > 0 ? addressWidth : nil,
                    alignment: .leading
                )
            }
            .contextMenu {
                BrowserPageMenu(store: store, favourites: favourites)
            }

            Spacer()

            Button {
                // Snapshot before the flip: once the transition starts the page
                // is already collapsing.
                store.captureSelectedTabSnapshot()
                withAnimation(BrowserTabSwitcher.transitionAnimation) {
                    store.isShowingTabSwitcher = true
                }
            } label: {
                BrowserTabCountLabel(count: store.tabs.count)
            }
            .accessibilityLabel(String(localized: "Tabs.Title", table: "Browser"))
        }
    }
}
