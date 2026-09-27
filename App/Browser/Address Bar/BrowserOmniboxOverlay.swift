import EnhancedNavigation
import SwiftUI

/// Reads `isActive` in its own body so opening the omnibox doesn't
/// re-evaluate the shell, and with it every tab's stack, on the first frame.
struct BrowserOmniboxOverlay: View {

    @Environment(BrowserTabStore.self) private var store
    @Environment(BrowserOmniboxModel.self) private var omnibox

    var body: some View {
        if omnibox.isActive, !store.isShowingTabSwitcher {
            BrowserOmniboxView()
                .transition(.opacity)
        }
    }
}
