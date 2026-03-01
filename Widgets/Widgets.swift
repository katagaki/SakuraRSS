import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct ArticleEntry: TimelineEntry {
    let date: Date
    let articles: [WidgetArticle]
    let feedTitle: String?
}

struct WidgetArticle: Identifiable {
    let id: Int64
    let title: String
    let feedName: String
    let publishedDate: Date?
    let isRead: Bool
}

// MARK: - Provider

struct ArticleProvider: TimelineProvider {

    func placeholder(in context: Context) -> ArticleEntry {
        ArticleEntry(
            date: Date(),
            articles: [
                WidgetArticle(
                    id: 0, title: "Loading articles...",
                    feedName: "Feed", publishedDate: Date(), isRead: false
                )
            ],
            feedTitle: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ArticleEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ArticleEntry>) -> Void) {
        let entry = loadEntry()
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60)))
        completion(timeline)
    }

    private func loadEntry() -> ArticleEntry {
        let database = DatabaseManager.shared
        do {
            let articles = try database.unreadArticles(limit: 10)
            let feeds = try database.allFeeds()

            let widgetArticles = articles.map { article in
                let feedName = feeds.first { $0.id == article.feedID }?.title ?? ""
                return WidgetArticle(
                    id: article.id,
                    title: article.title,
                    feedName: feedName,
                    publishedDate: article.publishedDate,
                    isRead: article.isRead
                )
            }

            return ArticleEntry(date: Date(), articles: widgetArticles, feedTitle: nil)
        } catch {
            return ArticleEntry(date: Date(), articles: [], feedTitle: nil)
        }
    }
}

// MARK: - Widget Views

struct ArticleWidgetView: View {

    @Environment(\.widgetFamily) var family
    var entry: ArticleProvider.Entry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            MediumWidgetView(entry: entry)
        }
    }
}

struct MediumWidgetView: View {

    let entry: ArticleEntry

    var body: some View {
        if entry.articles.isEmpty {
            VStack(spacing: 4) {
                Image(systemName: "newspaper")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(String(localized: "Widget.NoArticles"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "dot.radiowaves.up.forward")
                        .font(.caption)
                        .foregroundStyle(.pink)
                    Text(String(localized: "Shared.AppName"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.pink)
                    Spacer()
                    Text(String(localized: "Widget.Unread \(entry.articles.count)"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                ForEach(entry.articles.prefix(3)) { article in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(article.title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Text(article.feedName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}

struct LargeWidgetView: View {

    let entry: ArticleEntry

    var body: some View {
        if entry.articles.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "newspaper")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(String(localized: "Widget.NoArticles"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "dot.radiowaves.up.forward")
                        .font(.caption)
                        .foregroundStyle(.pink)
                    Text(String(localized: "Shared.AppName"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.pink)
                    Spacer()
                    Text(String(localized: "Widget.Unread \(entry.articles.count)"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                ForEach(entry.articles.prefix(8)) { article in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(article.title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(2)

                        HStack(spacing: 4) {
                            Text(article.feedName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if let date = article.publishedDate {
                                Text("·")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Text(date, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    if article.id != entry.articles.prefix(8).last?.id {
                        Divider()
                    }
                }
            }
        }
    }
}

// MARK: - Widget Definition

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

#Preview(as: .systemMedium) {
    SakuraRSSWidget()
} timeline: {
    ArticleEntry(date: .now, articles: [
        WidgetArticle(
            id: 1, title: "Sample Article Title",
            feedName: "Tech Blog", publishedDate: Date(), isRead: false
        ),
        WidgetArticle(
            id: 2, title: "Another Article",
            feedName: "News Site", publishedDate: Date(), isRead: false
        )
    ], feedTitle: nil)
}
