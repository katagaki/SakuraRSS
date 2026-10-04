import Hanami

enum AddressProgress {

    /// Content extraction first, then the page's own refresh, then a refresh
    /// of everything that isn't tied to a page, such as the one at launch.
    static func current(
        for location: BrowserLocation,
        feedManager: FeedManager,
        activity: BrowserPageActivity
    ) -> BrowserAddressProgress? {
        if activity.isExtractingContent {
            return .indeterminate
        }
        let scope = location.refreshScope(in: feedManager)
        if let state = feedManager.scopedRefreshes[scope.key], state.hasActiveProgress {
            return state.completed == 0 ? .indeterminate : .determinate(state.progress)
        }
        if feedManager.isLoading {
            guard feedManager.refreshTotal > 0, feedManager.refreshCompleted > 0 else { return .indeterminate }
            return .determinate(Double(feedManager.refreshCompleted) / Double(feedManager.refreshTotal))
        }
        return nil
    }
}
