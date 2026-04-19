import Foundation

extension FeedManager {

    private static let debouncedReadFlushDelay: Duration = .milliseconds(400)

    // MARK: - Debounced Mark As Read

    /// Applies the read state in memory immediately and queues the row's ID
    /// for a batched SQLite write + UI reload once scrolling settles.
    func markReadDebounced(_ article: Article) {
        if let idx = articles.firstIndex(where: { $0.id == article.id }),
           !articles[idx].isRead {
            articles[idx].isRead = true
            decrementUnreadCount(feedID: articles[idx].feedID)
        }
        pendingReadIDs.insert(article.id)
        scheduleDebouncedReadFlush()
    }

    func flushDebouncedReads() {
        debouncedReadFlushTask?.cancel()
        debouncedReadFlushTask = nil
        guard !pendingReadIDs.isEmpty else { return }
        let ids = Array(pendingReadIDs)
        pendingReadIDs.removeAll()
        let dbm = database
        Task.detached(priority: .utility) { [weak self] in
            // Two batched UPDATEs (one for the read flag, one for the
            // access timestamp) instead of 2N per-row statements — keeps
            // CPU and disk light even when dozens of rows scroll past in
            // quick succession.
            try? dbm.markArticlesRead(ids: ids, read: true)
            try? dbm.updateLastAccessed(articleIDs: ids)
            // Skip the UI-side reload: `markReadDebounced` already applied
            // the read state and unread-count decrement to the in-memory
            // arrays, so `articles` + `unreadCounts` already match what a
            // reload would produce. Just nudge anything observing
            // `dataRevision` and refresh the badge.
            await MainActor.run {
                self?.bumpDataRevision()
                self?.updateBadgeCount()
            }
        }
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
