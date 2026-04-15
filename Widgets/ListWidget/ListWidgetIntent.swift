import AppIntents
import WidgetKit

struct ListWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("ListWidget.IntentTitle", table: "Widget")
    static var description: IntentDescription = LocalizedStringResource("ListWidget.IntentDescription", table: "Widget")

    @Parameter(title: LocalizedStringResource("ListWidget.Parameter.List", table: "Widget"))
    var list: ListEntity?

    @Parameter(title: LocalizedStringResource("SingleFeedWidget.Parameter.Layout", table: "Widget"), default: .thumbnails)
    var layout: SingleFeedWidgetLayout?

    @Parameter(title: LocalizedStringResource("SingleFeedWidget.Parameter.Columns", table: "Widget"), default: .three)
    var columns: SingleFeedWidgetColumns?
}

struct ListWidgetPageIntent: AppIntent {

    static var title: LocalizedStringResource = LocalizedStringResource("ListWidget.ChangePage", table: "Widget")
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
