import SwiftUI
import WidgetKit

struct AllArticlesWidget: Widget {
    let kind = "SakuraRSSWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ArticleProvider()) { entry in
            ArticleWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Widget.DisplayName")
        .description("Widget.Description")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
