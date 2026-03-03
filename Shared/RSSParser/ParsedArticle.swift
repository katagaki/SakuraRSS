import Foundation

nonisolated struct ParsedArticle: Sendable {
    var title: String
    var url: String
    var author: String?
    var summary: String?
    var content: String?
    var imageURL: String?
    var publishedDate: Date?
    var audioURL: String?
    var duration: Int?
}
