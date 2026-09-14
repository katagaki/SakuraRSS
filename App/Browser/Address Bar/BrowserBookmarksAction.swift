import SwiftUI

private struct BrowserBookmarksActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// Presents the bookmarks sheet. Provided by the shell so the bottom bar
    /// can reach it from inside any tab's navigation stack.
    var browserBookmarksAction: (() -> Void)? {
        get { self[BrowserBookmarksActionKey.self] }
        set { self[BrowserBookmarksActionKey.self] = newValue }
    }
}
