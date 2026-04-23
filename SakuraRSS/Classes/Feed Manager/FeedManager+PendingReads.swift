import Foundation

extension FeedManager {

    private static let persistReadsDelay: Duration = .milliseconds(100)

    /// Enqueues the article for a debounced flush that writes SQLite and
    /// updates in-memory state in the same pass so `articles(for:)`
    /// re-queries see the fresh state on the next `dataRevision` tick.
    func markReadOnScroll(_ article: Article) {
        guard pendingReadIDs.insert(article.id).inserted else { return }
        schedulePersistReads()
    }

    func flushDebouncedReads() {
        debouncedReadFlushTask?.cancel()
        debouncedReadFlushTask = nil
        guard !pendingReadIDs.isEmpty else { return }
        let ids = pendingReadIDs
        pendingReadIDs.removeAll()
        let idArray = Array(ids)

        try? database.markArticlesRead(ids: idArray, read: true)

        var newArticles = articles
        var decrements: [Int64: Int] = [:]
        let indexByID = Dictionary(
            uniqueKeysWithValues: newArticles.enumerated().map { ($1.id, $0) }
        )
        for id in ids {
            guard let idx = indexByID[id], !newArticles[idx].isRead else { continue }
            newArticles[idx].isRead = true
            decrements[newArticles[idx].feedID, default: 0] += 1
        }
        articles = newArticles
        applyUnreadDecrements(decrements)
        bumpDataRevision()
        updateBadgeCount()

        let dbm = database
        Task.detached(priority: .utility) {
            try? dbm.updateLastAccessed(articleIDs: idArray)
        }
    }

    private func schedulePersistReads() {
        guard debouncedReadFlushTask == nil else { return }
        debouncedReadFlushTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: FeedManager.persistReadsDelay)
            guard !Task.isCancelled, let self else { return }
            self.flushDebouncedReads()
        }
    }

}
