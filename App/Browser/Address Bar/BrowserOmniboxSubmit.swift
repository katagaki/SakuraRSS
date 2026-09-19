import SwiftUI

private struct BrowserOmniboxSubmitKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// Runs the omnibox's Go action. The field lives in the bottom toolbar, so
    /// the shell hands its submit handler down the same way.
    var browserOmniboxSubmit: (() -> Void)? {
        get { self[BrowserOmniboxSubmitKey.self] }
        set { self[BrowserOmniboxSubmitKey.self] = newValue }
    }
}
