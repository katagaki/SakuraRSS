import SwiftUI
import Hanami

/// The Bookmarks page's trailing toolbar actions, for its omnibox menu. The
/// browser hides the top bar, so this is where they appear instead.
struct BrowserBookmarksActions {

    var createFolder: () -> Void
    var export: (() -> Void)?
    var removeReadBookmarks: (() -> Void)?
    var scope: Binding<BookmarkSmartGroup>
    var sortOrder: Binding<BookmarkSortOrder>
    var displayStyle: Binding<FeedDisplayStyle>
    var hasImages: Bool
}
