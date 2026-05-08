import AppIntents
import Foundation

struct ArticleEntity: AppEntity, Identifiable, Sendable {

    static let typeDisplayRepresentation: TypeDisplayRepresentation =
        TypeDisplayRepresentation(name: LocalizedStringResource("Article", table: "AppIntents"))
    static let defaultQuery = ArticleQuery()

    let id: String
    let articleID: Int64
    let title: String
    let author: String?
    let summary: String?
    let url: URL?
    let publishedDate: Date?
    let isRead: Bool
    let isBookmarked: Bool
    let feedTitle: String?

    init(article: Article, feedTitle: String?) {
        self.id = String(article.id)
        self.articleID = article.id
        self.title = article.title
        self.author = article.author
        self.summary = article.summary.map { ContentBlock.stripMarkdown($0) }
        self.url = URL(string: article.url)
        self.publishedDate = article.publishedDate
        self.isRead = article.isRead
        self.isBookmarked = article.isBookmarked
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
