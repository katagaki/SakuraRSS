import SwiftUI
import WidgetKit

// MARK: - Main Widget View

struct ListWidgetView: View {

    @Environment(\.widgetFamily) var family
    var entry: ListWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            ListWidgetSmallView(entry: entry)
                .padding(16)
        case .systemMedium:
            if entry.layout == .thumbnails {
                ListWidgetMediumThumbnailsView(entry: entry)
            } else {
                ListWidgetMediumTextView(entry: entry)
            }
        case .systemLarge:
            if entry.layout == .thumbnails {
                ListWidgetLargeThumbnailsView(entry: entry)
            } else {
                ListWidgetLargeTextView(entry: entry)
            }
        default:
            ListWidgetSmallView(entry: entry)
        }
    }
}

// MARK: - Widget Definition

struct ListWidget: Widget {
    let kind = "ListWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ListWidgetIntent.self,
            provider: ListWidgetProvider()
        ) { entry in
            ListWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color("WidgetBackground")
                }
        }
        .contentMarginsDisabled()
        .configurationDisplayName("ListWidget.DisplayName")
        .description("ListWidget.Description")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
