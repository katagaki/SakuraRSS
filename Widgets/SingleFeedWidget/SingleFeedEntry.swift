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
    let feedTitle: String
    let articles: [SingleFeedArticle]
    let layout: SingleFeedWidgetLayout
}
