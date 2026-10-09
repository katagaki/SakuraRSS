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
        HStack(spacing: 0) {
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
                    .environment(
                        \.browserOmniboxMenuInsets,
                        EdgeInsets(top: 0, leading: 6, bottom: 0, trailing: Self.contentInset)
                    )
                    .transition(.opacity)
            }
        }
        .animation(BrowserLocationLabel.contentChange, value: items.hasOmniboxAccessory)
        // Even by construction: both the icon and the glyph sit flush
        // against this inset, so neither side needs a fudge factor. As far
        // in from the capsule's ends as a `.bottomBar` item's content sat.
        // The menu takes the trailing inset into its own label to stay tappable
        // out to the capsule's end.
        .padding(.leading, Self.contentInset)
        .padding(.trailing, items.hasOmniboxAccessory ? 0 : Self.contentInset)
        .frame(maxWidth: .infinity, minHeight: TabBottomBarMetrics.itemHeight)
        // Behind the label rather than over the page: the browser has no
        // room for Home's refresh pill, so the bar itself reports the work.
        .background {
            BrowserAddressProgressBackground(progress: slots.displayedProgress(for: tabID, in: store))
        }
        .animation(.smooth, value: slots.displayedProgress(for: tabID, in: store) == nil)
    }

    private static let contentInset: CGFloat = 17
}
