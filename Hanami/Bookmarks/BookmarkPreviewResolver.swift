import Foundation

/// Finds a preview image for a saved page. Bookmarks saved from outside the app
/// have no feed to inherit artwork from, so the page's own Open Graph image is
/// the only thing standing between a bookmark and a blank row.
public nonisolated enum BookmarkPreviewResolver {

    /// Looks up one bookmark's preview image and records the outcome.
    @discardableResult
    public static func resolvePreview(forArticleID articleID: Int64, url: String) async -> String? {
        guard let parsed = URL(string: url) else {
            try? DatabaseManager.shared.setBookmarkPreview(
                imageURL: nil, state: .unavailable, forArticleID: articleID
            )
            return nil
        }
        let imageURL = await HTMLMetadataImage.fetchImageURL(for: parsed)
        try? DatabaseManager.shared.setBookmarkPreview(
            imageURL: imageURL,
            state: imageURL == nil ? .unavailable : .resolved,
            forArticleID: articleID
        )
        return imageURL
    }

    /// Fills in previews for bookmarks saved before the lookup existed, and for
    /// any that arrived while the app wasn't running, a few pages at a time.
    /// Returns how many previews were found, so callers only refresh for those.
    @concurrent
    @discardableResult
    public static func backfillPendingPreviews(limit: Int = 25, concurrentLookups: Int = 4) async -> Int {
        let pending = (try? DatabaseManager.shared.bookmarkIDsNeedingPreview(limit: limit)) ?? []
        guard !pending.isEmpty else { return 0 }
        return await withTaskGroup(of: Bool.self) { group in
            var remaining = pending[...]
            var found = 0
            for _ in 0..<min(concurrentLookups, remaining.count) {
                let bookmark = remaining.removeFirst()
                group.addTask { await resolvePreview(forArticleID: bookmark.id, url: bookmark.url) != nil }
            }
            for await didFind in group {
                if didFind { found += 1 }
                guard !Task.isCancelled, let bookmark = remaining.popFirst() else { continue }
                group.addTask { await resolvePreview(forArticleID: bookmark.id, url: bookmark.url) != nil }
            }
            return found
        }
    }

    /// Drops the "already tried" mark before looking again, for the manual action.
    @discardableResult
    public static func refreshPreview(forArticleID articleID: Int64, url: String) async -> String? {
        try? DatabaseManager.shared.resetBookmarkPreviewState(forArticleID: articleID)
        return await resolvePreview(forArticleID: articleID, url: url)
    }
}
