import Foundation
import WidgetKit

struct SingleFeedArticle: Identifiable {
    let id: Int64
    let title: String
    let imageData: Data?
    let publishedDate: Date?
}

struct SingleFeedEntry: TimelineEntry {
    let date: Date
    let feedID: Int64
    let feedTitle: String
    let articles: [SingleFeedArticle]
    let layout: SingleFeedWidgetLayout
    let currentPage: Int
    let totalPages: Int
}
