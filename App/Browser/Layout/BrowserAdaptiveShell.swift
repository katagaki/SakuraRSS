import EnhancedNavigation
import SwiftUI
import Hanami

/// EnhancedNavigation's shell: the zoom switcher and bottom bar on iPhone,
/// its tab strip and top bar on iPad and Mac.
struct BrowserAdaptiveShell: View {

    @Environment(FeedManager.self) private var feedManager
    @Environment(BrowserTabStore.self) private var store
    @Environment(BrowserFavourites.self) private var favourites
    @Environment(BrowserOmniboxModel.self) private var omnibox
    @Environment(\.browserOmniboxAction) private var openOmnibox

    private var isEditingAddress: Binding<Bool> {
        Binding {
            omnibox.isActive
        } set: { isEditing in
            if isEditing {
                openOmnibox?()
            } else {
                withAnimation(BrowserOmniboxModel.transition) { omnibox.deactivate() }
            }
        }
    }

    private var edgeToEdgeEdges: Edge.Set {
        BrowserLayout.usesWideTabs ? [] : .all
    }

    var body: some View {
        AdaptiveTabContainer(store: store, cardCornerRadius: TabSwitcherCardMetrics.cornerRadius) {
            BrowserTabSwitcher()
                .environment(store)
                .environment(favourites)
        } page: { _ in
            tabStack
        } tabLabel: { tab in
            BrowserLocationLabel(
                description: BrowserLocationDescription.describe(
                    tab, feedManager: feedManager, prefersContentTitle: true
                ),
                iconSize: 18,
                titleFont: .subheadline,
                showsSubtitle: false
            )
        }
        .tabOmniboxEditing(isEditing: isEditingAddress) {
            BrowserOmniboxEditingField()
        }
        .tabOmniboxPopup {
            BrowserOmniboxPopupContent()
        }
        // Container only: swallowing the keyboard region too leaves the
        // bottom bar, and so the address field, under the keyboard.
        .ignoresSafeArea(.container, edges: edgeToEdgeEdges)
        // One per shell, not one per page: mounted per page, the overlay and
        // its focused field can end up on screen twice. Outside the safe area
        // override, or with the keyboard down the editing bar rests against
        // the screen's edge instead of above the home indicator.
        .overlay {
            if !BrowserLayout.usesWideTabs {
                BrowserOmniboxOverlay()
            }
        }
    }

    private var tabStack: some View {
        BrowserTabStack()
            // Edge to edge, or the snapshot carries blank status bar and home
            // indicator bands into the card.
            .ignoresSafeArea(.container, edges: edgeToEdgeEdges)
            .environment(\.isBrowserChromeActive, true)
    }
}
