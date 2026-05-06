import Foundation

struct ParsedInstagramPost: Sendable {
    let id: String
    let text: String
    let author: String
    let authorHandle: String
    let url: String
    let imageURL: String?
    /// Includes the primary imageURL; empty for single-image posts.
    let carouselImageURLs: [String]
    let publishedDate: Date?
}
