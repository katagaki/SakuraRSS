import CoreSpotlight
import StoreKit
import SwiftUI
import Hanami

extension SakuraRSSApp {

    static let navigationStateKeys: [String] = [
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
}
