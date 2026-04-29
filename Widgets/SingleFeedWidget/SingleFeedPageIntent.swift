import AppIntents
import WidgetKit

struct SingleFeedPageIntent: AppIntent {

    static let title: LocalizedStringResource = LocalizedStringResource("SingleFeedWidget.ChangePage", table: "Widget")
    static let isDiscoverable: Bool = false

    @Parameter(title: "Feed ID")
    var feedID: Int

    @Parameter(title: "Page")
    var page: Int

    init() {
        self.feedID = 0
        self.page = 0
    }

    init(feedID: Int64, page: Int) {
        self.feedID = Int(feedID)
        self.page = page
    }

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.tsubuzaki.SakuraRSS")
        defaults?.set(page, forKey: "singleFeedPage_\(feedID)")
        WidgetCenter.shared.reloadTimelines(ofKind: "SingleFeedWidget")
        return .result()
    }
}
