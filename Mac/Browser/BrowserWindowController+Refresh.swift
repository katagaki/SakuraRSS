import AppKit
import Hanami

/// Refreshes the feeds behind the page on screen, as pulling to refresh does
/// on iOS.
extension BrowserWindowController: RefreshActions {

    var isCurrentPageRefreshing: Bool {
        let scope = history.current.refreshScope(in: feedManager)
        return feedManager.scopedRefreshes[scope.key]?.hasActiveProgress == true || feedManager.isLoading
    }

    func refreshFeeds(_ sender: Any?) {
        let scope = history.current.refreshScope(in: feedManager)
        Task {
            await feedManager.refreshFeeds(scope: scope.key, feeds: scope.feeds, runNLP: true)
        }
    }

    func stopRefreshing(_ sender: Any?) {
        let scope = history.current.refreshScope(in: feedManager)
        if feedManager.scopedRefreshes[scope.key] != nil {
            feedManager.cancelScopedRefresh(scope: scope.key)
        } else {
            feedManager.cancelRefresh()
        }
    }
}
