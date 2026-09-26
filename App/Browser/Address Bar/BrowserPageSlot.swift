import EnhancedNavigation
import SwiftUI

/// What a page hands the address bar, tagged with the page that sent it.
/// SwiftUI re-runs `onAppear` on the page *below* the one a pop reveals, so an
/// untagged report from a background page would take the bar over.
enum BrowserPageSlotReport {
    case markAllRead(BrowserMarkAllReadAction?)
    case bookmarks(BrowserBookmarksActions?)
    case following(BrowserFollowingActions?)
    case startPage(BrowserStartPageActions?)
    case displayStyle(BrowserDisplayStyleOptions?)
    case progress(BrowserAddressProgress?)
}

typealias BrowserPageSlot<Value> = PageSlot<BrowserPathToken, Value>

private struct BrowserPageSlotReporterKey: EnvironmentKey {
    static let defaultValue: ((BrowserPageSlotReport, BrowserPathToken?) -> Void)? = nil
}

extension EnvironmentValues {
    /// Installed once per tab; the page modifier wraps it into the per-kind
    /// reporters that pages call, adding the sender's token.
    var browserPageSlotReporter: ((BrowserPageSlotReport, BrowserPathToken?) -> Void)? {
        get { self[BrowserPageSlotReporterKey.self] }
        set { self[BrowserPageSlotReporterKey.self] = newValue }
    }
}
