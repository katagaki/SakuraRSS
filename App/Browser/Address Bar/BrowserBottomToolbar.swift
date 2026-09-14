import SwiftUI
import Hanami

/// The compact chrome, as a real `.bottomBar` toolbar rather than a floating
/// overlay, so it gets the system's glass, safe area and scroll behaviour.
struct BrowserBottomToolbar: ToolbarContent {

    let store: BrowserTabStore
    let feedManager: FeedManager
    let favourites: BrowserFavourites
    let onOpenOmnibox: () -> Void
    /// Measured by the shell: toolbar items size to their content, so the
    /// address item cannot stretch on its own.
    let addressWidth: CGFloat

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            Button {
                store.goBack()
            } label: {
                Image(systemName: "chevron.backward")
            }
            .disabled(!store.selectedTab.canGoBack)
            .accessibilityLabel(String(localized: "AddressBar.Back", table: "Browser"))

            Spacer()

            Button(action: onOpenOmnibox) {
                BrowserLocationLabel(
                    description: BrowserLocationDescription.describe(
                        store.selectedTab,
                        feedManager: feedManager
                    ),
                    iconSize: 16,
                    titleFont: .subheadline,
                    showsSubtitle: false
                )
                .frame(width: addressWidth > 0 ? addressWidth : nil)
            }
            .layoutPriority(1)
            .contextMenu {
                BrowserPageMenu(store: store, favourites: favourites)
            }

            Spacer()

            Button {
                withAnimation(.smooth.speed(1.5)) {
                    store.isShowingTabSwitcher = true
                }
            } label: {
                BrowserTabCountLabel(count: store.tabs.count)
            }
            .accessibilityLabel(String(localized: "Tabs.Title", table: "Browser"))
        }
    }
}
