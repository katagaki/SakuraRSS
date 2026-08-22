import Foundation

/// Slices a preloaded list of `ArticleIDEntry` values into the visible window
/// described by the user's `BatchingMode`. Decoupling the preload (full ID list)
/// from the presentation (batched slice) keeps "load more" O(1) and avoids
/// re-querying the database every time the limit grows.
public nonisolated struct ArticleIDBatcher: Sendable {
    public let entries: [ArticleIDEntry]

    public init(entries: [ArticleIDEntry]) {
        self.entries = entries
    }

    /// Count-based slice: first `limit` IDs in published-date order.
    public func ids(limit: Int) -> [Int64] {
        guard limit > 0 else { return [] }
        return entries.prefix(limit).map(\.id)
    }

    /// Date-based slice: every entry whose published date is on or after `date`.
    /// Undated entries are intentionally excluded; views surface those via a
    /// dedicated undated query.
    public func ids(since date: Date) -> [Int64] {
        entries
            .filter { ($0.publishedDate ?? .distantPast) >= date }
            .map(\.id)
    }

    /// Next visible count, or `nil` if there is nothing more to reveal.
    public func nextLoadedCount(after count: Int, batchSize: Int) -> Int? {
        guard entries.count > count else { return nil }
        return min(count + batchSize, entries.count)
    }

    /// Walks backwards in `chunkDays` windows until a window with at least one
    /// preloaded entry is found, returning that window's start date.
    public func nextChunkStart(before date: Date, chunkDays days: Int) -> Date? {
        guard days > 0 else { return nil }
        let calendar = Calendar.current
        var cursor = date
        var iterations = 0
        let maxIterations = 365 * 2
        while iterations < maxIterations {
            iterations += 1
            guard let newStart = calendar.date(byAdding: .day, value: -days, to: cursor) else {
                return nil
            }
            let index = firstIndexOlder(than: cursor)
            guard index < entries.count else { return nil }
            if (entries[index].publishedDate ?? .distantPast) >= newStart { return newStart }
            cursor = newStart
        }
        return nil
    }

    /// `entries` is preloaded in published-date-descending order, so the first
    /// entry older than `date` bounds every remaining candidate.
    private func firstIndexOlder(than date: Date) -> Int {
        var low = 0
        var high = entries.count
        while low < high {
            let middle = low + (high - low) / 2
            if (entries[middle].publishedDate ?? .distantPast) < date {
                high = middle
            } else {
                low = middle + 1
            }
        }
        return low
    }
}
