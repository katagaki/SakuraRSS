import Foundation

extension FeedManager {

    private static let persistReadsDelay: Duration = .milliseconds(500)

    /// Flips the article to read in memory immediately and enqueues the ID
    /// for a debounced SQLite write so fast scrolls don't thrash the disk.
    func markReadOnScroll(_ article: Article) {
        guard pendingReadIDs.insert(article.id).inserted else { return }

        if let idx = articles.firstIndex(where: { $0.id == article.id }),
           !articles[idx].isRead {
            let feedID = articles[idx].feedID
            articles[idx].isRead = true
            if let current = unreadCounts[feedID], current > 0 {
                unreadCounts[feedID] = current - 1
            }
            updateBadgeCount()
        }

        schedulePersistReads()
    }

    /// Persists queued read-state flips to SQLite and clears the queue.
    /// Also called from `willResignActive` before the app backgrounds.
    func flushDebouncedReads() {
        debouncedReadFlushTask?.cancel()
        debouncedReadFlushTask = nil
        guard !pendingReadIDs.isEmpty else { return }
        let idArray = Array(pendingReadIDs)
        pendingReadIDs.removeAll()

        let dbm = database
        Task.detached(priority: .utility) {
            try? dbm.markArticlesRead(ids: idArray, read: true)
            try? dbm.updateLastAccessed(articleIDs: idArray)
        }
    }

    private func schedulePersistReads() {
        debouncedReadFlushTask?.cancel()
        debouncedReadFlushTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: FeedManager.persistReadsDelay)
            guard !Task.isCancelled, let self else { return }
            self.flushDebouncedReads()
        }
    }

}
