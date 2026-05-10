import Foundation

/// Lightweight (id, publishedDate) pair preloaded for a feed/section/list before
/// the user's batching settings carve out a visible slice.
public nonisolated struct ArticleIDEntry: Hashable, Sendable {
    public let id: Int64
    public let publishedDate: Date?
}
