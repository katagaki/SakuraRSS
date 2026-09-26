import SwiftUI

private struct BrowserBookmarksActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// Pushes Bookmarks onto the selected tab. Provided by the shell for the
    /// regular layout's address row; compact reaches it from Today instead.
    var browserBookmarksAction: (() -> Void)? {
        get { self[BrowserBookmarksActionKey.self] }
        set { self[BrowserBookmarksActionKey.self] = newValue }
    }
}
