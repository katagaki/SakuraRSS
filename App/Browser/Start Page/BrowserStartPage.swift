import SwiftUI
import Hanami

/// The new-tab landing. Today carries the page, with Favourites pinned above it.
struct BrowserStartPage: View {

    var body: some View {
        #if os(visionOS)
        // visionOS has no Today, so the start page keeps its own sections there.
        BrowserFallbackStartPage()
        #else
        TodayView(headerView: AnyView(
            BrowserFavouritesSection()
                .padding(.horizontal, 20)
                .padding(.top, 12)
        ))
        #endif
    }
}
