import AppIntents
import WidgetKit

struct SingleFeedIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = LocalizedStringResource("SingleFeedWidget.IntentTitle", table: "Widget")
    static let description: IntentDescription = IntentDescription(
        LocalizedStringResource("SingleFeedWidget.IntentDescription", table: "Widget")
    )

    @Parameter(
        title: LocalizedStringResource("SingleFeedWidget.Parameter.Feed", table: "Widget")
    )
    var feed: FeedEntity?

    @Parameter(
        title: LocalizedStringResource("SingleFeedWidget.Parameter.Layout", table: "Widget"),
        default: .thumbnails
    )
    var layout: SingleFeedWidgetLayout?

    @Parameter(
        title: LocalizedStringResource("SingleFeedWidget.Parameter.Columns", table: "Widget"),
        default: .three
    )
    var columns: SingleFeedWidgetColumns?
}
