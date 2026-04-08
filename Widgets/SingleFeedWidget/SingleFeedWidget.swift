import SwiftUI
import WidgetKit

// MARK: - Main Widget View

struct SingleFeedWidgetView: View {

    @Environment(\.widgetFamily) var family
    var entry: SingleFeedEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SingleFeedSmallView(entry: entry)
                .padding(16)
        case .systemMedium:
            if entry.layout == .thumbnails {
                SingleFeedMediumThumbnailsView(entry: entry)
            } else {
                SingleFeedMediumTextView(entry: entry)
            }
        case .systemLarge:
            if entry.layout == .thumbnails {
                SingleFeedLargeThumbnailsView(entry: entry)
            } else {
                SingleFeedLargeTextView(entry: entry)
            }
        default:
            SingleFeedSmallView(entry: entry)
        }
    }
}

// MARK: - Widget Definition

struct SingleFeedWidget: Widget {
    let kind = "SingleFeedWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SingleFeedIntent.self,
            provider: SingleFeedProvider()
        ) { entry in
            SingleFeedWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color("WidgetBackground")
                }
        }
        .contentMarginsDisabled()
        .configurationDisplayName("SingleFeedWidget.DisplayName")
        .description("SingleFeedWidget.Description")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
