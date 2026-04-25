import Foundation

extension FeedManager {

    static let pendingReadsDebounceInterval: DispatchTimeInterval = .milliseconds(250)

    /// True if persisted as read or queued for the next flush.
    func isRead(_ article: Article) -> Bool {
        article.isRead || pendingReadIDs.contains(article.id)
    }

    func markReadOnScroll(_ article: Article) {
        guard !article.isRead,
              pendingReadIDs.insert(article.id).inserted else { return }
        decrementUnreadCount(feedID: article.feedID)
        updateBadgeCount()
        schedulePendingReadsFlush()
    }

    func flushDebouncedReads() {
        pendingReadsFlushWorkItem?.cancel()
        pendingReadsFlushWorkItem = nil
        guard !pendingReadIDs.isEmpty else { return }
        let ids = pendingReadIDs
        pendingReadIDs.removeAll()
        let idArray = Array(ids)

        try? database.markArticlesRead(ids: idArray, read: true)
        bumpDataRevision()

        let dbm = database
        Task.detached(priority: .utility) {
            try? dbm.updateLastAccessed(articleIDs: idArray)
        }
    }

    /// Coalesces rapid scroll-driven mark-read events into one DB write per debounce window.
    private func schedulePendingReadsFlush() {
        guard pendingReadsFlushWorkItem == nil else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.flushDebouncedReads()
        }
        pendingReadsFlushWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.pendingReadsDebounceInterval,
            execute: workItem
        )
    }

}
