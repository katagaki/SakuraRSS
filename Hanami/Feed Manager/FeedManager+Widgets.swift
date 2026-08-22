import WidgetKit

public extension FeedManager {

    func reloadWidgetTimelines() {
        guard !DatabaseManager.isRunningInAppExtension else { return }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
