import AppIntents
import WidgetKit

struct SingleFeedIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "SingleFeedWidget.IntentTitle"
    static var description: IntentDescription = "SingleFeedWidget.IntentDescription"

    @Parameter(title: "SingleFeedWidget.Parameter.Feed")
    var feed: FeedEntity?

    @Parameter(title: "SingleFeedWidget.Parameter.Layout", default: .thumbnails)
    var layout: SingleFeedWidgetLayout?
}
