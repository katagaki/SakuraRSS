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
        let ids = pendingReadIDs
        pendingReadIDs.removeAll()
        let dbm = database
        Task.detached(priority: .utility) { [weak self] in
            for id in ids {
                try? dbm.markArticleRead(id: id, read: true)
                try? dbm.updateLastAccessed(articleID: id)
            }
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
