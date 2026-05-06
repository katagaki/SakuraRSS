import Foundation

struct ParsedReply: Sendable {
    let id: String
    let text: String
    let author: String
    let authorHandle: String
    let url: String
    let publishedDate: Date?
}
