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

    private var editingItems: some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            BrowserOmniboxField(
                model: omnibox,
                width: BrowserAddressMetrics.fieldWidth(forAddressWidth: addressWidth),
                onSubmit: onSubmitOmnibox
            )

            Spacer()

            Button(String(localized: "AddressField.Cancel", table: "Browser")) {
                omnibox.deactivate()
            }
        }
    }

    private var browsingItems: some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            Button(action: onOpenBookmarks) {
                Image(systemName: "bookmark")
            }
            .accessibilityLabel(String(localized: "Location.Bookmarks", table: "Browser"))

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
