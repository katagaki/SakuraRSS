import Foundation
import WidgetKit

struct ListWidgetArticle: Identifiable {
    let id: Int64
    let title: String
    let imageData: Data?
    let publishedDate: Date?
}

struct ListWidgetEntry: TimelineEntry {
    let date: Date
    let listID: Int64
    let listTitle: String
    let articles: [ListWidgetArticle]
    let layout: SingleFeedWidgetLayout
    let columns: Int
    let currentPage: Int
    let totalPages: Int
}
