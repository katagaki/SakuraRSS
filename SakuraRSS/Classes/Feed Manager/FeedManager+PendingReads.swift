import Foundation

extension FeedManager {

    /// True if the article is persisted as read or queued for the next flush.
    func isRead(_ article: Article) -> Bool {
        article.isRead || pendingReadIDs.contains(article.id)
    }

    /// Queues the article for a flush that fires the next time scrolling
    /// goes idle, so continuous scrolls don't trigger re-render cascades
    /// that break auto-load-on-scroll and drop visibility callbacks.
    func markReadOnScroll(_ article: Article) {
        pendingReadIDs.insert(article.id)
    }

    /// Fired from the scroll-phase idle transition and from willResignActive.
    func flushDebouncedReads() {
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

}
