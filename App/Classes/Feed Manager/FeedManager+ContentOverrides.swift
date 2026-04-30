import Foundation

extension FeedManager {

    /// Reads the cached or persisted override for a feed. Cache is populated lazily on first read.
    func contentOverride(forFeedID feedID: Int64) -> ContentOverride? {
        if let cached = contentOverrideCache[feedID] {
            return cached.override
        }
        let stored = (try? database.contentOverride(forFeedID: feedID)) ?? nil
        contentOverrideCache[feedID] = .init(override: stored)
        return stored
    }

    /// Persists or clears the override and refreshes the in-memory cache.
    /// Pass `nil` to delete the row.
    func setContentOverride(_ override: ContentOverride?, forFeedID feedID: Int64) {
        if let override {
            try? database.upsertContentOverride(override)
            contentOverrideCache[feedID] = .init(override: override)
        } else {
            try? database.deleteContentOverride(forFeedID: feedID)
            contentOverrideCache[feedID] = .init(override: nil)
        }
    }
}

/// Tiny wrapper so a missing-row lookup is distinguishable from "not yet checked" in the cache.
struct CachedContentOverride: Sendable {
    let override: ContentOverride?
}
