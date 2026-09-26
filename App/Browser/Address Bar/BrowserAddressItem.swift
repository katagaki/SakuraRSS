import EnhancedNavigation
import SwiftUI
import Hanami

/// The page's name and, when the page declared one, its omnibox accessory
/// sharing the same capsule.
struct BrowserAddressItem: View {

    @Environment(FeedManager.self) private var feedManager
    let store: BrowserTabStore
    let slots: BrowserPageSlots
    let tabID: UUID
    let favourites: BrowserFavourites
    /// What the visible page declared with `tabOmniboxAccessory`.
    let items: TabBottomBarItems
    let onOpenOmnibox: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onOpenOmnibox) {
                BrowserLocationLabel(
                    description: BrowserLocationDescription.describe(
                        store.displayedTab(for: tabID),
                        feedManager: feedManager
                    ),
                    iconSize: 24,
                    titleFont: .subheadline,
                    showsSubtitle: true
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if items.hasOmniboxAccessory {
                items.omniboxAccessory
                    .transition(.opacity)
            }
        }
        .animation(BrowserLocationLabel.contentChange, value: items.hasOmniboxAccessory)
        // Even by construction: both the icon and the glyph sit flush
        // against this padding, so neither side needs a fudge factor. As far
        // in from the capsule's ends as a `.bottomBar` item's content sat.
        .padding(.horizontal, 17)
        .frame(maxWidth: .infinity, minHeight: TabBottomBarMetrics.itemHeight)
        // Behind the label rather than over the page: the browser has no
        // room for Home's refresh pill, so the bar itself reports the work.
        .background {
            BrowserAddressProgressBackground(progress: slots.displayedProgress(for: tabID, in: store))
        }
        .animation(.smooth, value: slots.displayedProgress(for: tabID, in: store) == nil)
    }
}
