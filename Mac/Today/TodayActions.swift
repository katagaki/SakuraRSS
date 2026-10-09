import Foundation
import Hanami

/// How Today's tiles, rows and cards hand a destination back to their tab.
struct TodayActions {
    let open: (BrowserLocation) -> Void
    let openInNewTab: (BrowserLocation) -> Void
    var showBookmarkDetails: (Article) -> Void = { _ in }
    var moveToFolder: (Article) -> Void = { _ in }
    var editQuickAccess: () -> Void = {}
}
