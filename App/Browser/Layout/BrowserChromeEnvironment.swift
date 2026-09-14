import SwiftUI

private struct BrowserChromeActiveKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// True while a view is hosted by the browser shell's bottom bar, which
    /// already names the page. Feed and list views drop their principal title
    /// so the name is not shown twice.
    var isBrowserChromeActive: Bool {
        get { self[BrowserChromeActiveKey.self] }
        set { self[BrowserChromeActiveKey.self] = newValue }
    }
}
