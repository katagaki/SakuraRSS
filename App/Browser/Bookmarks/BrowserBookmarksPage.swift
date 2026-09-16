import SwiftUI
import Hanami

/// Bookmarks as a page pushed onto the current tab, rather than a sheet over
/// it: the back gesture and the tab's own history then apply to it like any
/// other page.
struct BrowserBookmarksDestination: Hashable, Codable {}

struct BrowserBookmarksPage: View {

    var body: some View {
        BookmarksContentView(titleDisplayMode: .inline)
            .environment(\.navigateToFeed, { _ in })
    }
}
