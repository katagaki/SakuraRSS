import Foundation

public struct ParsedReply: Sendable {
    public let id: String
    public let text: String
    public let author: String
    public let authorHandle: String
    public let url: String
    public let publishedDate: Date?
}
