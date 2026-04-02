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
            ZStack(alignment: .bottom) {
                Group {
                    if entry.layout == .thumbnails {
                        SingleFeedMediumThumbnailsView(entry: entry)
                    } else {
                        SingleFeedMediumTextView(entry: entry)
                    }
                }
                .padding(16)
                if entry.layout == .thumbnails {
                    FeedTitleLabel(title: entry.feedTitle)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 2)
                }
            }
        case .systemLarge:
            ZStack(alignment: .bottom) {
                Group {
                    if entry.layout == .thumbnails {
                        SingleFeedLargeThumbnailsView(entry: entry)
                    } else {
                        SingleFeedLargeTextView(entry: entry)
                    }
                }
                .padding(16)
                if entry.layout == .thumbnails {
                    FeedTitleLabel(title: entry.feedTitle)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 2)
                }
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
        .configurationDisplayName(String(localized: "SingleFeedWidget.DisplayName"))
        .description(String(localized: "SingleFeedWidget.Description"))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
