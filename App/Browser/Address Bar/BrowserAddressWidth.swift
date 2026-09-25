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

    /// The height of the glass a `.bottomBar` item draws, which the address
    /// item's own content stops short of. Only the progress fill needs it:
    /// anything less leaves a bare strip above and below the bar.
    static let glassHeight: CGFloat = 48

    /// How far that glass overhangs the item's content at each end, measured
    /// off a rendered bar. The progress fill is outset by it, or the glass
    /// keeps a bare strip at both ends however full the bar reads.
    static let glassHorizontalOverhang: CGFloat = 5

    static func addressWidth(forContainerWidth width: CGFloat) -> CGFloat {
        max(0, width - chromeWidth)
    }
}
