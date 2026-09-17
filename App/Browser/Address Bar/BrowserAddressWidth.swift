import SwiftUI

private struct BrowserAddressWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// Toolbar items size to their content, so `maxWidth: .infinity` does
    /// nothing there and the shell has to measure the space and hand it down.
    var browserAddressWidth: CGFloat {
        get { self[BrowserAddressWidthKey.self] }
        set { self[BrowserAddressWidthKey.self] = newValue }
    }
}

enum BrowserAddressMetrics {
    /// Everything in the bar that is not the address item.
    static let chromeWidth: CGFloat = 190

    /// The back button and the gap after it. At a tab's root there is no back
    /// button, and the address item takes the room rather than leaving a hole.
    ///
    /// Measured against the rendered bar rather than derived: raising it much
    /// further overflows the group and the system folds the tab count into an
    /// overflow menu, so it has to be rechecked if `chromeWidth` changes.
    static let leadingButtonWidth: CGFloat = 59

    /// The tappable square inside that button's glass.
    static let leadingButtonHeight: CGFloat = 44

    static func addressWidth(forContainerWidth width: CGFloat) -> CGFloat {
        max(0, width - chromeWidth)
    }
}
