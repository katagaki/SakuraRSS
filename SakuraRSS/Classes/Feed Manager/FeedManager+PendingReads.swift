import Foundation

extension FeedManager {

    private static let debouncedReadFlushDelay: Duration = .milliseconds(400)

    // MARK: - Debounced Mark As Read

    func markReadDebounced(_ article: Article) {
        guard pendingReadIDs.insert(article.id).inserted else { return }
        scheduleDebouncedReadFlush()
    }

    func flushDebouncedReads() {
        debouncedReadFlushTask?.cancel()
        debouncedReadFlushTask = nil
        guard !pendingReadIDs.isEmpty else { return }
        let ids = pendingReadIDs
        pendingReadIDs.removeAll()

        let indexByID = Dictionary(uniqueKeysWithValues: articles.enumerated().map { ($1.id, $0) })
        for id in ids {
            guard let idx = indexByID[id], !articles[idx].isRead else { continue }
            articles[idx].isRead = true
            decrementUnreadCount(feedID: articles[idx].feedID)
        }
        updateBadgeCount()

        let idArray = Array(ids)
        let dbm = database
        Task.detached(priority: .utility) {
            try? dbm.markArticlesRead(ids: idArray, read: true)
            try? dbm.updateLastAccessed(articleIDs: idArray)
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
