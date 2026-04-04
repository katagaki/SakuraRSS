import AppIntents
import WidgetKit

struct SingleFeedPageIntent: AppIntent {

    static var title: LocalizedStringResource = "SingleFeedWidget.ChangePage"

    @Parameter(title: "Feed ID")
    var feedID: Int64

    @Parameter(title: "Page")
    var page: Int

    init() {
        self.feedID = 0
        self.page = 0
    }

    init(feedID: Int64, page: Int) {
        self.feedID = feedID
        self.page = page
    }

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.tsubuzaki.SakuraRSS")
        defaults?.set(page, forKey: "singleFeedPage_\(feedID)")
        WidgetCenter.shared.reloadTimelines(ofKind: "SingleFeedWidget")
        return .result()
    }
}
