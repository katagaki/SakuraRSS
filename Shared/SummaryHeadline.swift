import Foundation

/// One headline card in the summary carousel: a grouped event with its
/// thumbnail, contributing feed icons, and the article IDs it covers.
nonisolated struct SummaryHeadline: Hashable, Sendable, Identifiable {
    let id: UUID
    let headline: String
    let articleIDs: [Int64]
    let thumbnailURL: String?
    let feedIDs: [Int64]

    init(
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
