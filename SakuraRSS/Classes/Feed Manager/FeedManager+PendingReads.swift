import Foundation

extension FeedManager {

    /// True if persisted as read or queued for the next flush.
    func isRead(_ article: Article) -> Bool {
        article.isRead || pendingReadIDs.contains(article.id)
    }

    func markReadOnScroll(_ article: Article) {
        guard !article.isRead,
              pendingReadIDs.insert(article.id).inserted else { return }
        decrementUnreadCount(feedID: article.feedID)
        updateBadgeCount()
    }

    func flushDebouncedReads() {
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

}
