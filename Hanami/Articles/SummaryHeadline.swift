import Foundation

/// One headline card in the summary carousel: a grouped event with its
/// thumbnail, contributing feed icons, and the article IDs it covers.
public nonisolated struct SummaryHeadline: Hashable, Sendable, Identifiable {
    public let id: UUID
    public let headline: String
    public let articleIDs: [Int64]
    public let thumbnailURL: String?
    public let feedIDs: [Int64]

    public init(
        id: UUID = UUID(),
        headline: String,
        articleIDs: [Int64],
        thumbnailURL: String?,
        feedIDs: [Int64]
    ) {
        self.id = id
        self.headline = headline
        self.articleIDs = articleIDs
        self.thumbnailURL = thumbnailURL
        self.feedIDs = feedIDs
    }
}
