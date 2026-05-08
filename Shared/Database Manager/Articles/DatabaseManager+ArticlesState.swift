import Foundation
@preconcurrency import SQLite

nonisolated extension DatabaseManager {

    func markArticleRead(id: Int64, read: Bool) throws {
        let target = articles.filter(articleID == id)
        try database.run(target.update(articleIsRead <- read))
    }

    /// Batched counterpart of `markArticleRead(id:read:)`.
    func markArticlesRead(ids: [Int64], read: Bool) throws {
        guard !ids.isEmpty else { return }
        let target = articles.filter(ids.contains(articleID))
        try database.run(target.update(articleIsRead <- read))
    }

    func toggleBookmark(id: Int64) throws {
        guard let row = try database.pluck(articles.filter(articleID == id)) else { return }
        let current = row[articleIsBookmarked]
        try database.run(articles.filter(articleID == id).update(articleIsBookmarked <- !current))
    }

    /// Idempotent bookmark setter used by App Intents.
    /// Returns `true` when the stored value actually changed.
    @discardableResult
    func setBookmarked(id: Int64, bookmarked: Bool) throws -> Bool {
        guard let row = try database.pluck(articles.filter(articleID == id)) else { return false }
        let current = row[articleIsBookmarked]
        guard current != bookmarked else { return false }
        try database.run(articles.filter(articleID == id).update(articleIsBookmarked <- bookmarked))
        return true
    }

    func removeReadBookmarks() throws {
        let target = articles.filter(articleIsBookmarked == true && articleIsRead == true)
        try database.run(target.update(articleIsBookmarked <- false))
    }

    func markAllRead(feedID fid: Int64) throws {
        let target = articles.filter(articleFeedID == fid && articleIsRead == false)
        try database.run(target.update(articleIsRead <- true))
    }

    func markAllRead() throws {
        let target = articles.filter(articleIsRead == false)
        try database.run(target.update(articleIsRead <- true))
    }

    func markAllUnread() throws {
        let target = articles.filter(articleIsRead == true)
        try database.run(target.update(articleIsRead <- false))
    }

    func unreadCount(forFeedID fid: Int64) throws -> Int {
        try database.scalar(articles.filter(articleFeedID == fid && articleIsRead == false).count)
    }

    func totalUnreadCount() throws -> Int {
        try database.scalar(articles.filter(articleIsRead == false).count)
    }

    func allUnreadCounts() throws -> [Int64: Int] {
        var counts: [Int64: Int] = [:]
        let query = "SELECT feed_id, COUNT(*) FROM articles WHERE is_read = 0 GROUP BY feed_id"
        for row in try database.prepare(query) {
            if let feedID = row[0] as? Int64, let count = row[1] as? Int64 {
                counts[feedID] = Int(count)
            }
        }
        return counts
    }

    /// Per-feed count of unread articles whose URL marks them as Instagram reels.
    /// Used to subtract reels from the displayed unread count when the user hides them.
    func unreadReelsCounts(forFeedIDs feedIDs: Set<Int64>) throws -> [Int64: Int] {
        guard !feedIDs.isEmpty else { return [:] }
        let inClause = feedIDs.map { String($0) }.joined(separator: ",")
        let query = """
            SELECT feed_id, COUNT(*) FROM articles \
            WHERE is_read = 0 AND feed_id IN (\(inClause)) AND url LIKE '%/reel/%' \
            GROUP BY feed_id
            """
        var counts: [Int64: Int] = [:]
        for row in try database.prepare(query) {
            if let feedID = row[0] as? Int64, let count = row[1] as? Int64 {
                counts[feedID] = Int(count)
            }
        }
        return counts
    }
}
