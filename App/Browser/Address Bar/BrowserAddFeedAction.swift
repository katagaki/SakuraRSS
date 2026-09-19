import SwiftUI

private struct BrowserAddFeedActionKey: EnvironmentKey {
    static let defaultValue: ((String) -> Void)? = nil
}

extension EnvironmentValues {
    /// Hands a site address to the Add Feed sheet.
    var browserAddFeedAction: ((String) -> Void)? {
        get { self[BrowserAddFeedActionKey.self] }
        set { self[BrowserAddFeedActionKey.self] = newValue }
    }
}
