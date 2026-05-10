import Foundation

struct ParsedInstagramComment: Sendable {
    let id: String
    let text: String
    let author: String
    let authorHandle: String
    let likeCount: Int
    let publishedDate: Date?
    let sourceURL: String?
}
