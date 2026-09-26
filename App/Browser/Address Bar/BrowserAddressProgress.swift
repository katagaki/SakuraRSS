import SwiftUI
import Hanami

/// What the address bar draws behind its label while the page it is naming is
/// busy. The browser has no room for Home's refresh pill, so the omnibox's own
/// background carries the progress instead.
enum BrowserAddressProgress: Equatable {
    case determinate(Double)
    /// Work that cannot be counted, or cannot be counted yet: the bar runs a
    /// marquee rather than parking a bar at zero.
    case indeterminate
}

private struct BrowserPageProgressReporterKey: EnvironmentKey {
    static let defaultValue: ((BrowserAddressProgress?) -> Void)? = nil
}

extension EnvironmentValues {
    /// Called by a page that tracks its own work, such as the article viewer
    /// while it extracts.
    var browserPageProgressReporter: ((BrowserAddressProgress?) -> Void)? {
        get { self[BrowserPageProgressReporterKey.self] }
        set { self[BrowserPageProgressReporterKey.self] = newValue }
    }
}

/// Publishes a feed refresh scope as the page's progress. Applied where the
/// browser wraps a page rather than inside the page, so the app's own views
/// stay unaware of the browser.
private struct BrowserRefreshScopeModifier: ViewModifier {

    @Environment(FeedManager.self) private var feedManager
    @Environment(\.browserPageSlotReporter) private var slotReporter
    @Environment(\.browserPathToken) private var pathToken
    let scope: String

    private var progress: BrowserAddressProgress? {
        guard let state = feedManager.scopedRefreshes[scope], state.hasActiveProgress else {
            return nil
        }
        // A scope that has counted its feeds but finished none of them has
        // nothing to draw yet, and a bar pinned at zero reads as stalled.
        return state.completed == 0 ? .indeterminate : .determinate(state.progress)
    }

    func body(content: Content) -> some View {
        content
            // No report on disappear: the page revealed by a pop re-appears
            // and re-reports, and a departing page's nil would land after it.
            .onAppear { slotReporter?(.progress(progress), pathToken) }
            .onChange(of: progress) { slotReporter?(.progress(progress), pathToken) }
    }
}

extension View {
    /// Draws the named refresh scope's progress in the address bar while this
    /// page is the one the bar is naming.
    func browserRefreshScope(_ scope: String) -> some View {
        modifier(BrowserRefreshScopeModifier(scope: scope))
    }
}
