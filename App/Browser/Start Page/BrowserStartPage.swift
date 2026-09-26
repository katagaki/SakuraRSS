import EnhancedNavigation
import SwiftUI
import Hanami

/// The new-tab landing. Today carries the page, with the shortcut grid and
/// recent content pinned directly below the greeting.
struct BrowserStartPage: View {

    @Environment(FeedManager.self) private var feedManager
    @Environment(\.isBrowserChromeActive) private var isBrowserChromeActive
    @State private var isPresentingNewListSheet = false

    var body: some View {
        #if os(visionOS)
        // visionOS has no Today, so the start page keeps its own sections there.
        BrowserFallbackStartPage()
        #else
        TodayView(pinnedSection: AnyView(
            VStack(alignment: .leading, spacing: 16) {
                BrowserTodayShortcutsGrid()
                BrowserRecentContentSection()
            }
            .padding(.horizontal)
        ))
        .tabOmniboxAccessory(isEnabled: isBrowserChromeActive) {
            BrowserStartPageMenu(actions: BrowserStartPageActions(
                newList: { isPresentingNewListSheet = true }
            ))
        }
        .sheet(isPresented: $isPresentingNewListSheet) {
            ListEditSheet(list: nil)
                .environment(feedManager)
                .presentationDetents([.large])
                .interactiveDismissDisabled()
        }
        #endif
    }
}
