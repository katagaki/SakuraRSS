import SwiftUI
import Hanami

/// The new-tab landing. Today carries the page, with the shortcut grid and
/// recent content pinned directly below the greeting.
struct BrowserStartPage: View {

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
        #endif
    }
}
