import SwiftUI

private struct BrowserModeActiveKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// True anywhere inside the browser shell, on any layout.
    var isBrowserModeActive: Bool {
        get { self[BrowserModeActiveKey.self] }
        set { self[BrowserModeActiveKey.self] = newValue }
    }
}
