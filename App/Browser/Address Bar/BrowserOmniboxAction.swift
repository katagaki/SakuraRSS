import SwiftUI

private struct BrowserOmniboxActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// Opens the omnibox. Provided by the shell so the bottom toolbar can reach
    /// it from inside any tab's navigation stack.
    var browserOmniboxAction: (() -> Void)? {
        get { self[BrowserOmniboxActionKey.self] }
        set { self[BrowserOmniboxActionKey.self] = newValue }
    }
}
