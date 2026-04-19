import Foundation

extension FeedManager {

    private static let debouncedReadFlushDelay: Duration = .milliseconds(400)

    // MARK: - Debounced Mark As Read

    /// Queues the article's ID for a batched in-memory + SQLite update once
    /// scrolling settles. Mutating @Observable state here would force the
    /// article list to re-evaluate on every row that leaves the viewport.
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

        // All @Observable writes in one synchronous pass so SwiftUI coalesces
        // the dependent view updates into a single tick instead of one per row.
        let indexByID = Dictionary(uniqueKeysWithValues: articles.enumerated().map { ($1.id, $0) })
        for id in ids {
            guard let idx = indexByID[id], !articles[idx].isRead else { continue }
            articles[idx].isRead = true
            decrementUnreadCount(feedID: articles[idx].feedID)
        }
        updateBadgeCount()

        // Two batched UPDATEs (read flag + access timestamp) instead of 2N
        // per-row statements.
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
