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
    static let leadingButtonWidth: CGFloat = 44

    static func addressWidth(forContainerWidth width: CGFloat) -> CGFloat {
        max(0, width - chromeWidth)
    }

    /// The field sits beside one cancel button rather than two round ones.
    static func fieldWidth(forAddressWidth width: CGFloat) -> CGFloat {
        max(0, width + 76)
    }
}
