import SwiftUI
import Hanami

/// The Bookmarks page's trailing toolbar actions, handed to the bottom bar.
/// The browser hides the top bar, so this is where they appear instead.
struct BrowserBookmarksActions {

    var createFolder: () -> Void
    var export: (() -> Void)?
    var removeReadBookmarks: (() -> Void)?
    var sortOrder: Binding<BookmarkSortOrder>
    var displayStyle: Binding<FeedDisplayStyle>
    var hasImages: Bool
}

private struct BrowserBookmarksActionsReporterKey: EnvironmentKey {
    static let defaultValue: ((BrowserBookmarksActions?) -> Void)? = nil
}

extension EnvironmentValues {
    /// The Bookmarks page calls this to offer its actions to the bottom bar.
    var browserBookmarksActionsReporter: ((BrowserBookmarksActions?) -> Void)? {
        get { self[BrowserBookmarksActionsReporterKey.self] }
        set { self[BrowserBookmarksActionsReporterKey.self] = newValue }
    }
}
