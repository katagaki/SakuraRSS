import SwiftUI

private struct BrowserModeActiveKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

private struct BrowserChromeActiveKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// True anywhere inside the browser shell, on any layout. Distinct from
    /// `isBrowserChromeActive`, which only covers the compact layout where
    /// the browser replaces the page's own chrome.
    var isBrowserModeActive: Bool {
        get { self[BrowserModeActiveKey.self] }
        set { self[BrowserModeActiveKey.self] = newValue }
    }

    /// True while a view is hosted by the browser shell's bottom bar, which
    /// already names the page. Feed and list views drop their principal title
    /// so the name is not shown twice.
    var isBrowserChromeActive: Bool {
        get { self[BrowserChromeActiveKey.self] }
        set { self[BrowserChromeActiveKey.self] = newValue }
    }
}

extension SearchFieldPlacement {
    /// Under the browser's chrome a page's search field goes up into the
    /// hidden top bar: the omnibox is how the browser searches, and left to
    /// itself the field claims the bottom edge the browser's bar sits on.
    static func browserChrome(isActive: Bool) -> SearchFieldPlacement {
        isActive ? .navigationBarDrawer : .automatic
    }
}
