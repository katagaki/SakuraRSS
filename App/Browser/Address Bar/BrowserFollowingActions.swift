import SwiftUI
import Hanami

/// The Following page's top bar controls, handed to the bottom bar. The
/// browser hides the top bar in compact layout, so this is where adding a
/// feed, making a list and the edit/select modes appear instead.
struct BrowserFollowingActions {

    var addFeed: () -> Void
    var newList: () -> Void
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

private struct BrowserFollowingActionsReporterKey: EnvironmentKey {
    static let defaultValue: ((BrowserFollowingActions?) -> Void)? = nil
}

extension EnvironmentValues {
    /// The Following page calls this to offer its controls to the bottom bar.
    var browserFollowingActionsReporter: ((BrowserFollowingActions?) -> Void)? {
        get { self[BrowserFollowingActionsReporterKey.self] }
        set { self[BrowserFollowingActionsReporterKey.self] = newValue }
    }
}
