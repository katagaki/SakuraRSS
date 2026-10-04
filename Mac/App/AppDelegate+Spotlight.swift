import AppKit
import CoreSpotlight
import Hanami

extension AppDelegate {

    func application(
        _ application: NSApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([any NSUserActivityRestoring]) -> Void
    ) -> Bool {
        guard userActivity.activityType == CSSearchableItemActionType,
              let articleID = SpotlightIndexer.articleID(from: userActivity) else {
            return false
        }
        openContent(articleID)
        return true
    }
}
