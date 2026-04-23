import Foundation

extension FeedManager {

    private static let debouncedReadFlushDelay: Duration = .milliseconds(500)
    private static let scrollSettleRecheckDelay: Duration = .milliseconds(150)
    private static let maxScrollSettleWaitCycles: Int = 40

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
        let idArray = Array(ids)

        // Persist before publishing observable changes so re-reads via `dataRevision` see the update.
        try? database.markArticlesRead(ids: idArray, read: true)

        var newArticles = articles
        var decrements: [Int64: Int] = [:]
        let indexByID = Dictionary(uniqueKeysWithValues: newArticles.enumerated().map { ($1.id, $0) })
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

    private func scheduleDebouncedReadFlush() {
        debouncedReadFlushTask?.cancel()
        debouncedReadFlushTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: FeedManager.debouncedReadFlushDelay)
            guard !Task.isCancelled, let self else { return }
            var cycles = 0
            while !self.isScrollSettled, cycles < FeedManager.maxScrollSettleWaitCycles {
                try? await Task.sleep(for: FeedManager.scrollSettleRecheckDelay)
                guard !Task.isCancelled else { return }
                cycles += 1
            }
            self.flushDebouncedReads()
        }
    }

}
