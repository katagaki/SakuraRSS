import Foundation

extension FeedManager {

    /// Debounce window before a burst of mark-read-on-scroll updates
    /// triggers the full `loadFromDatabase()` + badge refresh.
    private static let debouncedReadFlushDelay: Duration = .milliseconds(400)

    // MARK: - Debounced Mark As Read

    /// Marks an article as read without triggering a full `loadFromDatabase()`
    /// or badge refresh on every call.  The DB row is still updated
    /// synchronously - so any view that re-queries after the `dataRevision`
    /// bump sees the correct state - but the expensive cascade is deferred
    /// until the user stops scrolling.
    ///
    /// Use this from scroll-driven callers like `MarkReadOnScrollModifier`
    /// where many articles can be marked in quick succession.  Explicit
    /// user actions (tapping the read button, mark all read) should keep
    /// using `markRead(_:)` so the UI updates immediately.
    func markReadDebounced(_ article: Article) {
        try? database.markArticleRead(id: article.id, read: true)
        try? database.updateLastAccessed(articleID: article.id)

        // Keep the in-memory caches consistent so lookups via
        // `article(byID:)` and `unreadCount(for:)` don't lie during
        // the debounce window.
        if let idx = articles.firstIndex(where: { $0.id == article.id }),
           !articles[idx].isRead {
            articles[idx].isRead = true
            let feedID = articles[idx].feedID
            if let count = unreadCounts[feedID], count > 0 {
                unreadCounts[feedID] = count - 1
            }
        }
        dataRevision += 1
        hasPendingDebouncedReads = true
        scheduleDebouncedReadFlush()
    }

    /// Flushes any pending debounced reads immediately.  Safe to call when
    /// nothing is pending.  Invoked on scene backgrounding to make sure the
    /// badge and in-memory caches are in sync before the app suspends.
    func flushDebouncedReads() {
        debouncedReadFlushTask?.cancel()
        debouncedReadFlushTask = nil
        guard hasPendingDebouncedReads else { return }
        hasPendingDebouncedReads = false
        loadFromDatabase()
        updateBadgeCount()
    }

    private func scheduleDebouncedReadFlush() {
        debouncedReadFlushTask?.cancel()
        debouncedReadFlushTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: FeedManager.debouncedReadFlushDelay)
            guard !Task.isCancelled else { return }
            self?.flushDebouncedReads()
        }
    }

}
