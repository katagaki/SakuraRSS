import SwiftUI

private struct BrowserAddressWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// Width the address item should claim in the bottom bar. Toolbar items are
    /// sized to their content, so `maxWidth: .infinity` does nothing there and
    /// the shell has to measure the space and hand it down.
    var browserAddressWidth: CGFloat {
        get { self[BrowserAddressWidthKey.self] }
        set { self[BrowserAddressWidthKey.self] = newValue }
    }
}

struct BrowserAddressWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

enum BrowserAddressMetrics {
    /// Everything in the bottom bar that is not the address item: the back and
    /// tab buttons, the two dividing spacers, and the bar's own side margins.
    static let chromeWidth: CGFloat = 190

    static func addressWidth(forContainerWidth width: CGFloat) -> CGFloat {
        max(0, width - chromeWidth)
    }

    /// The editing field sits beside Cancel rather than two round buttons,
    /// so it can claim a little more room than the address item.
    static func fieldWidth(forAddressWidth width: CGFloat) -> CGFloat {
        max(0, width - 16)
    }
}
