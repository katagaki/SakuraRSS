import SwiftUI

/// What a page hands the address bar, tagged with the page that sent it.
/// SwiftUI re-runs `onAppear` on the page *below* the one a pop reveals, so an
/// untagged report from a background page would take the bar over.
enum BrowserPageSlotReport {
    case markAllRead(BrowserMarkAllReadAction?)
    case article(BrowserArticleActions?)
    case bookmarks(BrowserBookmarksActions?)
    case following(BrowserFollowingActions?)
    case displayStyle(BrowserDisplayStyleOptions?)
}

/// A slot's contents, alongside the path token of the page that filled it.
struct BrowserPageSlot<Value> {
    let token: BrowserPathToken?
    let value: Value

    /// The value, but only for the page the bar is currently naming.
    func value(forPageAt token: BrowserPathToken?) -> Value? {
        self.token == token ? value : nil
    }
}

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
