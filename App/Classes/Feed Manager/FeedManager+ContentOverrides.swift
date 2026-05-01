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
        bumpDataRevision()
    }

    /// Applies the feed's override to each article. No-op when the override is missing or inactive.
    func applyContentOverrides(_ articles: [Article], feedID: Int64) -> [Article] {
        guard let override = contentOverride(forFeedID: feedID), override.isActive else {
            return articles
        }
        return articles.map { ContentOverrideApplier.applying(to: $0, override: override) }
    }

    /// Multi-feed variant; looks up each article's feed override on demand using the local cache.
    func applyContentOverrides(_ articles: [Article]) -> [Article] {
        var perFeed: [Int64: ContentOverride?] = [:]
        return articles.map { article in
            let override: ContentOverride?
            if let cached = perFeed[article.feedID] {
                override = cached
            } else {
                let resolved = contentOverride(forFeedID: article.feedID)
                perFeed[article.feedID] = resolved
                override = resolved
            }
            guard let override, override.isActive else { return article }
            return ContentOverrideApplier.applying(to: article, override: override)
        }
    }
}

/// Tiny wrapper so a missing-row lookup is distinguishable from "not yet checked" in the cache.
struct CachedContentOverride: Sendable {
    let override: ContentOverride?
}
