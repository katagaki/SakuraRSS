import SwiftUI
import WidgetKit

struct SakuraRSSWidget: Widget {
    let kind = "SakuraRSSWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ArticleProvider()) { entry in
            ArticleWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(String(localized: "Widget.DisplayName"))
        .description(String(localized: "Widget.Description"))
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
