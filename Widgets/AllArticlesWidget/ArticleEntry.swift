import Foundation
import WidgetKit

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
