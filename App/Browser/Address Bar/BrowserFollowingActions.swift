import SwiftUI
import Hanami

/// The Following page's top bar controls, for its omnibox menu. The browser
/// hides the top bar in compact layout, so this is where adding a feed and
/// the edit/select modes appear instead.
struct BrowserFollowingActions {

    var addFeed: () -> Void
    /// Nil while there is nothing to edit, which is also when the top bar
    /// disables its pencil.
    var beginEditing: (() -> Void)?
    var isEditing: Bool
    var isSelecting: Bool
    var toggleSelectMode: () -> Void
    var endEditing: () -> Void
    var selectedCount: Int
    var editSelected: () -> Void
    var deleteSelected: () -> Void
}
