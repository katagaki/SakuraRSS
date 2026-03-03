import Foundation

nonisolated struct ParsedFeed: Sendable {
    var title: String
    var siteURL: String
    var description: String
    var articles: [ParsedArticle]
    var isPodcast: Bool
}
