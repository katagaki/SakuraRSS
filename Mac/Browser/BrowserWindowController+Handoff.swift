import AppKit
import Hanami

/// Offers the content being read to nearby devices through Handoff, as a web
/// page, so they can carry on in Safari without anything app-specific.
extension BrowserWindowController {

    func updateHandoff(for article: Article?) {
        guard let article, let url = URL(string: article.url), url.scheme?.hasPrefix("http") == true else {
            window?.userActivity?.invalidate()
            window?.userActivity = nil
            return
        }
        let activity = window?.userActivity ?? NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        activity.webpageURL = url
        activity.title = article.displayTitle
        window?.userActivity = activity
        activity.becomeCurrent()
    }

    func updateHandoffForCurrentLocation() {
        if case .article(let articleID) = history.current {
            updateHandoff(for: feedManager.article(byID: articleID))
        } else {
            updateHandoff(for: nil)
        }
    }
}
