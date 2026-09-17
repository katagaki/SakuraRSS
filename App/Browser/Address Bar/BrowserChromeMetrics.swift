import Observation
import SwiftUI

/// The rendered bottom bar's geometry. The editing field is not a toolbar
/// item, so nothing else makes it the size of the bar it stands in for.
@MainActor
@Observable
final class BrowserChromeMetrics {

    /// The page's bottom safe area inset while the bar is up.
    var barInset: CGFloat = 0

    /// The address item's content, inside the glass the system draws for it.
    var addressContentHeight: CGFloat = 0

    private var band: CGFloat {
        max(0, barInset - BrowserDeviceMetrics.safeAreaInsets.bottom)
    }

    /// The band is the item's content, the glass padding around it, and the
    /// gap under the capsule. Only the band and the content can be measured,
    /// so the other two are taken as equal: `band = content + 4 * padding`.
    private var padding: CGFloat {
        guard addressContentHeight > 0, band > addressContentHeight else { return 0 }
        return (band - addressContentHeight) / 4
    }

    var fieldHeight: CGFloat? {
        padding > 0 ? addressContentHeight + padding * 2 : nil
    }
}
