import Foundation

/// How Today's tiles, rows and cards hand a destination back to their tab.
struct TodayActions {
    let open: (BrowserLocation) -> Void
    let openInNewTab: (BrowserLocation) -> Void
}
