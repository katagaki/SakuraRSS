import AppKit

@objc protocol RefreshActions {
    func refreshFeeds(_ sender: Any?)
    func stopRefreshing(_ sender: Any?)
}
