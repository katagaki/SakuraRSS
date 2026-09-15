import SwiftUI

/// A page's mark-all-read action, handed up to the bottom bar. Boxed because a
/// closure cannot be stored in a dictionary that the store compares.
struct BrowserMarkAllReadAction: Identifiable {
    let id = UUID()
    let perform: () -> Void
}

private struct BrowserMarkAllReadReporterKey: EnvironmentKey {
    static let defaultValue: ((BrowserMarkAllReadAction?) -> Void)? = nil
}

extension EnvironmentValues {
    /// Pages call this to offer their mark-all-read action to the bottom bar,
    /// which is the only place it appears once the top bar is gone.
    var browserMarkAllReadReporter: ((BrowserMarkAllReadAction?) -> Void)? {
        get { self[BrowserMarkAllReadReporterKey.self] }
        set { self[BrowserMarkAllReadReporterKey.self] = newValue }
    }
}
