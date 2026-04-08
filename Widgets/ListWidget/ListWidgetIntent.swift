import AppIntents
import WidgetKit

struct ListWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "ListWidget.IntentTitle"
    static var description: IntentDescription = "ListWidget.IntentDescription"

    @Parameter(title: "ListWidget.Parameter.List")
    var list: ListEntity?

    @Parameter(title: "SingleFeedWidget.Parameter.Layout", default: .thumbnails)
    var layout: SingleFeedWidgetLayout?

    @Parameter(title: "SingleFeedWidget.Parameter.Columns", default: .three)
    var columns: SingleFeedWidgetColumns?
}

struct ListWidgetPageIntent: AppIntent {

    static var title: LocalizedStringResource = "ListWidget.ChangePage"
    static var isDiscoverable: Bool = false

    @Parameter(title: "List ID")
    var listID: Int

    @Parameter(title: "Page")
    var page: Int

    init() {
        self.listID = 0
        self.page = 0
    }

    init(listID: Int64, page: Int) {
        self.listID = Int(listID)
        self.page = page
    }

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.tsubuzaki.SakuraRSS")
        defaults?.set(page, forKey: "listWidgetPage_\(listID)")
        WidgetCenter.shared.reloadTimelines(ofKind: "ListWidget")
        return .result()
    }
}
