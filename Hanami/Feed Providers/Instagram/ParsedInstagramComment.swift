import Foundation

public struct ParsedInstagramComment: Sendable {
    public let id: String
    public let text: String
    public let author: String
    public let authorHandle: String
    public let likeCount: Int
    public let publishedDate: Date?
    public let sourceURL: String?
}
