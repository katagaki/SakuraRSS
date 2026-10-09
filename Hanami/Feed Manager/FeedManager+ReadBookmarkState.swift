import Foundation

public extension FeedManager {

    func markRead(_ article: Article) {
        let articleID = article.id
        guard !isSettledAsRead(article) else {
            writeArticleState { databaseManager in
                try? databaseManager.updateLastAccessed(articleID: articleID)
            } completion: { [weak self] in
                self?.recentsRevision += 1
            }
            return
        }
        let wasRead = isRead(article)
        stagedReadChanges[articleID] = true
        cancelPendingScrollRead(for: article)
        writeArticleState { databaseManager in
            try? databaseManager.updateLastAccessed(articleID: articleID)
            try? databaseManager.markArticleRead(id: articleID, read: true)
        } completion: { [weak self] in
            self?.recentsRevision += 1
        }
        if !wasRead {
            adjustUnreadCount(for: article, delta: -1)
        }
        applyReadChangeToCachedArticle(id: articleID, isRead: true)
        readMaskRevision += 1
        updateBadgeCount()
    }

    func toggleRead(_ article: Article) {
        let articleID = article.id
        let newState = !isRead(article)
        stagedReadChanges[articleID] = newState
        cancelPendingScrollRead(for: article)
        writeArticleState { databaseManager in
            try? databaseManager.markArticleRead(id: articleID, read: newState)
        }
        adjustUnreadCount(for: article, delta: newState ? -1 : 1)
        applyReadChangeToCachedArticle(id: articleID, isRead: newState)
        readMaskRevision += 1
        updateBadgeCount()
    }

    func toggleBookmark(_ article: Article) {
        let articleID = article.id
        let newState = !isBookmarked(article)
        stagedBookmarkChanges[articleID] = newState
        writeArticleState { databaseManager in
            try? databaseManager.setBookmarked(id: articleID, bookmarked: newState)
        } completion: { [weak self] in
            self?.bumpDataRevision()
        }
        applyBookmarkChangeToCachedArticle(id: articleID, isBookmarked: newState)
        readMaskRevision += 1
        if newState {
            onBookmarkAdded?(article)
        }
    }

    private func applyReadChangeToCachedArticle(id: Int64, isRead: Bool) {
        guard let index = articles.firstIndex(where: { $0.id == id }) else { return }
        articles[index].isRead = isRead
    }

    private func applyBookmarkChangeToCachedArticle(id: Int64, isBookmarked: Bool) {
        guard let index = articles.firstIndex(where: { $0.id == id }) else { return }
        articles[index].isBookmarked = isBookmarked
    }

    /// Applies an unflushed scroll-read's pending unread decrement now, before the
    /// caller toggles read state, so `markRead`/`toggleRead`'s delta isn't dropped
    /// or double-counted.
    private func cancelPendingScrollRead(for article: Article) {
        pendingReadIDs.remove(article.id)
        guard unflushedReadIDs.remove(article.id) != nil else { return }
        if let count = pendingReadDecrements[article.feedID], count > 0 {
            pendingReadDecrements[article.feedID] = count - 1
        }
        if article.url.contains("/reel/"),
           let count = pendingReadReelsDecrements[article.feedID], count > 0 {
            pendingReadReelsDecrements[article.feedID] = count - 1
        }
        adjustUnreadCount(for: article, delta: -1)
    }
}
