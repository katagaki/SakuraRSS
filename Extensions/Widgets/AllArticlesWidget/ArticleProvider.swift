import WidgetKit
import Hanami

struct ArticleProvider: TimelineProvider {

    func placeholder(in _: Context) -> ArticleEntry {
        ArticleEntry(
            date: Date(),
            articles: [
                WidgetArticle(
                    id: 0,
                    title: String(localized: "Placeholder.Loading", table: "Widget"),
                    feedName: String(
                        localized: "Placeholder.Feed",
                        table: "Widget"
                    ),
                    publishedDate: Date(),
                    isRead: false
                )
            ],
            feedTitle: nil
        )
    }

    func getSnapshot(in _: Context, completion: @escaping (ArticleEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<ArticleEntry>) -> Void) {
        let entry = loadEntry()
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(90 * 60)))
        completion(timeline)
    }

    private func loadEntry() -> ArticleEntry {
        let database = DatabaseManager.shared
        do {
            let articles = try database.unreadArticlesList(limit: 10)
            let feedTitlesByID = Dictionary(
                try database.allFeeds().map { ($0.id, $0.title) },
                uniquingKeysWith: { first, _ in first }
            )

            let widgetArticles = articles.map { article in
                let feedName = feedTitlesByID[article.feedID] ?? ""
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
