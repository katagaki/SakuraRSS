import Foundation

extension FeedManager {

    static let pendingReadsDebounceInterval: DispatchTimeInterval = .milliseconds(250)

    /// True if persisted as read or queued for the next flush. Reads
    /// `readMaskRevision` so views refresh when the queue flushes, while
    /// individual scroll-driven inserts stay outside observation.
    func isRead(_ article: Article) -> Bool {
        _ = readMaskRevision
        return article.isRead || pendingReadIDs.contains(article.id)
    }

    func markReadOnScroll(_ article: Article) {
        guard !article.isRead,
              pendingReadIDs.insert(article.id).inserted else { return }
        pendingReadDecrements[article.feedID, default: 0] += 1
        schedulePendingReadsFlush()
    }

    func flushDebouncedReads() {
        pendingReadsFlushWorkItem?.cancel()
        pendingReadsFlushWorkItem = nil
        guard !pendingReadIDs.isEmpty else { return }
        let decrements = pendingReadDecrements
        pendingReadDecrements.removeAll()

        applyUnreadDecrements(decrements)
        updateBadgeCount()

        let idArray = Array(pendingReadIDs)
        readMaskRevision += 1

        let dbm = database
        Task.detached(priority: .utility) {
            try? dbm.markArticlesRead(ids: idArray, read: true)
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
