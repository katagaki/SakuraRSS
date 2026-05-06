import Foundation

struct ParsedTweet: Sendable {
    let id: String
    let text: String
    let author: String
    let authorHandle: String
    let url: String
    let imageURL: String?
    let carouselImageURLs: [String]
    let publishedDate: Date?
}
