import SwiftUI

/// The start page's actions, handed to the bottom bar's trailing menu.
struct BrowserStartPageActions {

    var newList: () -> Void
}

private struct BrowserStartPageActionsReporterKey: EnvironmentKey {
    static let defaultValue: ((BrowserStartPageActions?) -> Void)? = nil
}

extension EnvironmentValues {
    /// The start page calls this to offer its actions to the bottom bar.
    var browserStartPageActionsReporter: ((BrowserStartPageActions?) -> Void)? {
        get { self[BrowserStartPageActionsReporterKey.self] }
        set { self[BrowserStartPageActionsReporterKey.self] = newValue }
    }
}
