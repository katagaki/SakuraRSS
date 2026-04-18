import CoreSpotlight
import StoreKit
import SwiftUI

extension SakuraRSSApp {

    static let navigationStateKeys: [String] = [
        "App.SelectedTab",
        "Home.SelectedSection",
        "Home.FeedID",
        "Home.ArticleID",
        "FeedsList.FeedID",
        "FeedsList.ArticleID"
    ]

    static func resetSavedNavigationState(defaults: UserDefaults) {
        for key in navigationStateKeys {
            defaults.removeObject(forKey: key)
        }
    }

    func requestReviewIfNeeded() {
        let launchCount = UserDefaults.standard.integer(forKey: "App.LaunchCount")
        if launchCount == 3 {
            requestReview()
        }
    }

    /// Runs a one-time full Spotlight reindex when the on-device index
    /// schema doesn't match the current build's `SpotlightIndexer.schemaVersion`.
    /// Does NOT gate on Low Power Mode: if the schema has changed, search
    /// is broken until the reindex runs.  In the steady state - when the
    /// stored version already matches - this method is a single
    /// `UserDefaults` read and returns immediately.
    func reindexSpotlightIfSchemaChanged() {
        let defaults = UserDefaults.standard
        let storedRaw = defaults.object(forKey: SpotlightIndexer.schemaVersionDefaultsKey) as? Int
        guard storedRaw != SpotlightIndexer.schemaVersion else { return }

        SpotlightIndexer.removeAllArticles()
        feedManager.reindexAllArticlesInSpotlight()
        defaults.set(SpotlightIndexer.schemaVersion, forKey: SpotlightIndexer.schemaVersionDefaultsKey)
    }
}
