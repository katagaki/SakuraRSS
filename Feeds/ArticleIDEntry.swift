import Foundation

/// Lightweight (id, publishedDate) pair preloaded for a feed/section/list before
/// the user's batching settings carve out a visible slice.
nonisolated struct ArticleIDEntry: Hashable, Sendable {
    let id: Int64
    let publishedDate: Date?
}
