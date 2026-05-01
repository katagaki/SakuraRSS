import Foundation

extension EditFeedContentTab {

    func initializeStateIfNeeded() {
        guard !hasInitialized else { return }
        hasInitialized = true

        let openModeRaw = UserDefaults.standard.string(forKey: "openMode-\(feedID)")
        openMode = openModeRaw.flatMap(FeedOpenMode.init(rawValue:)) ?? .inAppViewer
        let articleSourceRaw = UserDefaults.standard.string(forKey: "articleSource-\(feedID)")
        articleSource = articleSourceRaw.flatMap(ArticleSource.init(rawValue:)) ?? .automatic

        if let stored = feedManager.contentOverride(forFeedID: feedID) {
            overridesEnabled = stored.enabled
            titleField = stored.titleField
            bodyField = stored.bodyField
            authorField = stored.authorField
        }
    }

    func commitOverrideIfNeeded() {
        guard hasInitialized else { return }
        if overridesEnabled {
            feedManager.setContentOverride(pendingOverride, forFeedID: feedID)
        } else {
            feedManager.setContentOverride(nil, forFeedID: feedID)
        }
    }
}
