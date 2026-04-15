import WidgetKit

struct ArticleProvider: TimelineProvider {

    func placeholder(in _: Context) -> ArticleEntry {
        ArticleEntry(
            date: Date(),
            articles: [
                WidgetArticle(
                    id: 0, title: String(localized: "Placeholder.Loading", table: "Widget"),
                    feedName: String(localized: "Placeholder.Feed", table: "Widget"), publishedDate: Date(), isRead: false
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
        // Timeline refreshes every 90 minutes instead of every 30.  Widgets
        // running outside the app process wake it on every reload; tripling
        // the interval triples the battery savings for this path.
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(90 * 60)))
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
