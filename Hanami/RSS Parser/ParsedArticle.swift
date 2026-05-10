import Foundation

public nonisolated struct ParsedArticle: Sendable {
    public var title: String
    public var url: String
    public var author: String?
    public var summary: String?
    public var content: String?
    public var imageURL: String?
    public var publishedDate: Date?
    public var audioURL: String?
    public var duration: Int?
}
