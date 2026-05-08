import AppIntents
import Foundation

struct BookmarkEntity: AppEntity, Identifiable, Sendable {

    static let typeDisplayRepresentation: TypeDisplayRepresentation =
        TypeDisplayRepresentation(name: LocalizedStringResource("Bookmark", table: "AppIntents"))
    static let defaultQuery = BookmarkQuery()

    let id: String
    let articleID: Int64
    let title: String
    let url: URL?
    let publishedDate: Date?
    let feedTitle: String?

    init(article: Article, feedTitle: String?) {
        self.id = String(article.id)
        self.articleID = article.id
        self.title = article.title
        self.url = URL(string: article.url)
        self.publishedDate = article.publishedDate
        self.feedTitle = feedTitle
    }

    var displayRepresentation: DisplayRepresentation {
        if let feedTitle, !feedTitle.isEmpty {
            DisplayRepresentation(title: "\(title)", subtitle: "\(feedTitle)")
        } else {
            DisplayRepresentation(title: "\(title)")
        }
    }
}
