import Foundation

public extension FeedManager {

    convenience init() {
        self.init(loadsFullState: true)
    }

    /// Category refreshes only read `feeds`, so background tasks skip loading
    /// articles, lists, and folders on the main thread.
    static func forBackgroundRefresh() -> FeedManager {
        FeedManager(loadsFullState: false)
    }
}
