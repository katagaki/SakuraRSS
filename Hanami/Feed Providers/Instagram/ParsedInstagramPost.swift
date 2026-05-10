import Foundation

public struct ParsedInstagramPost: Sendable {
    public let id: String
    public let text: String
    public let author: String
    public let authorHandle: String
    public let url: String
    public let imageURL: String?
    /// Includes the primary imageURL; empty for single-image posts.
    public let carouselImageURLs: [String]
    public let publishedDate: Date?
}
