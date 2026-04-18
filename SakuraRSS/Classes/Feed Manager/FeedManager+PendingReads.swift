import Foundation

extension FeedManager {

    private static let debouncedReadFlushDelay: Duration = .milliseconds(400)

    // MARK: - Debounced Mark As Read

    /// Writes the row immediately but defers the full reload + badge refresh
    /// until scrolling settles.
    func markReadDebounced(_ article: Article) {
        try? database.markArticleRead(id: article.id, read: true)
        try? database.updateLastAccessed(articleID: article.id)

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
