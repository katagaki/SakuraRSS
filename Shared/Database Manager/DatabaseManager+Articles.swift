import Foundation
@preconcurrency import SQLite

/// Groups optional article fields to keep the insert call under the parameter limit.
struct ArticleInsertData: Sendable {
    var author: String?
    var summary: String?
    var content: String?
    var imageURL: String?
    var carouselImageURLs: [String] = []
    var publishedDate: Date?
    var audioURL: String?
    var duration: Int?
}

/// A single article to be batch-inserted, pairing its required and optional fields.
struct ArticleInsertItem {
    var title: String
    var url: String
    var data: ArticleInsertData
}

nonisolated extension DatabaseManager {

    // MARK: - Article CRUD

    @discardableResult
    func insertArticle(
        feedID fid: Int64,
        title: String,
        url: String,
        data: ArticleInsertData = ArticleInsertData()
    ) throws -> Int64 {
        let carouselValue = data.carouselImageURLs.isEmpty
            ? nil : data.carouselImageURLs.joined(separator: "\n")
        return try database.run(articles.insert(or: .ignore,
            articleFeedID <- fid,
            articleTitle <- title,
            articleURL <- url,
            articleAuthor <- data.author,
            articleSummary <- data.summary,
            articleContent <- data.content,
            articleImageURL <- data.imageURL,
            articleCarouselURLs <- carouselValue,
            articlePublishedDate <- data.publishedDate?.timeIntervalSince1970,
            articleIsRead <- false,
            articleIsBookmarked <- false,
            articleAudioURL <- data.audioURL,
            articleDuration <- data.duration
        ))
    }

    @discardableResult
    func insertArticles(feedID fid: Int64, articles items: [ArticleInsertItem]) throws -> [Int64] {
        guard !items.isEmpty else { return [] }
        let cutoffTimestamp = UserDefaults.standard.double(forKey: "Content.CutoffDate")
        let cutoffDate: Date? = cutoffTimestamp > 0
            ? Date(timeIntervalSince1970: cutoffTimestamp) : nil
        var insertedIDs: [Int64] = []
        try database.transaction {
            for item in items {
                if let cutoff = cutoffDate, let published = item.data.publishedDate,
                   published < cutoff {
                    continue
                }
                let carouselValue = item.data.carouselImageURLs.isEmpty
                    ? nil : item.data.carouselImageURLs.joined(separator: "\n")
                let rowid = try database.run(articles.insert(or: .ignore,
                    articleFeedID <- fid,
                    articleTitle <- item.title,
                    articleURL <- item.url,
                    articleAuthor <- item.data.author,
                    articleSummary <- item.data.summary,
                    articleContent <- item.data.content,
                    articleImageURL <- item.data.imageURL,
                    articleCarouselURLs <- carouselValue,
                    articlePublishedDate <- item.data.publishedDate?.timeIntervalSince1970,
                    articleIsRead <- false,
                    articleIsBookmarked <- false,
                    articleAudioURL <- item.data.audioURL,
                    articleDuration <- item.data.duration
                ))
                // `INSERT OR IGNORE` on a URL-uniqueness conflict does not
                // change sqlite3_changes(), so we gate on the per-statement
                // change count rather than the returned rowid (which can
                // carry over from a prior statement).
                if database.changes > 0 {
                    insertedIDs.append(rowid)
                }
            }
        }
        return insertedIDs
    }

    /// Returns the articles with the given IDs, ordered by published date
    /// descending.  Used to look up just-inserted rows for Spotlight
    /// indexing so unchanged rows aren't re-indexed on every refresh.
    func articles(withIDs ids: [Int64]) throws -> [Article] {
        guard !ids.isEmpty else { return [] }
        let query = articles
            .filter(ids.contains(articleID))
            .order(articlePublishedDate.desc)
        return try database.prepare(query).map(rowToArticle)
    }

    /// Returns articles for a set of feed IDs ordered by published date
    /// descending.  Used by the list widgets so a single SQLite statement
    /// (with indexes on `feed_id` and `published_date`) replaces N
    /// per-feed queries merged and re-sorted in Swift.
    func articles(forFeedIDs feedIDs: [Int64], limit: Int) throws -> [Article] {
        guard !feedIDs.isEmpty else { return [] }
        let query = articles
            .filter(feedIDs.contains(articleFeedID))
            .order(articlePublishedDate.desc)
            .limit(limit)
        return try database.prepare(query).map(rowToArticle)
    }

    func article(byID id: Int64) throws -> Article? {
        let query = articles.filter(articleID == id).limit(1)
        return try database.prepare(query).map(rowToArticle).first
    }

    func articles(forFeedID fid: Int64, limit: Int? = nil) throws -> [Article] {
        var query = articles
            .filter(articleFeedID == fid)
            .order(articlePublishedDate.desc)
        if let limit {
            query = query.limit(limit)
        }
        return try database.prepare(query).map(rowToArticle)
    }

    func articleCount(forFeedID fid: Int64) throws -> Int {
        try database.scalar(articles.filter(articleFeedID == fid).count)
    }

    /// Returns the URLs already ingested for `fid` so refresh can skip
    /// per-article work (e.g. HTML metadata lookups) on known items.
    func existingArticleURLs(forFeedID fid: Int64) throws -> Set<String> {
        let query = articles
            .filter(articleFeedID == fid)
            .select(articleURL)
        var result = Set<String>()
        for row in try database.prepare(query) {
            result.insert(row[articleURL])
        }
        return result
    }

    func articles(forFeedID fid: Int64, since date: Date) throws -> [Article] {
        let query = articles
            .filter(articleFeedID == fid
                    && articlePublishedDate >= date.timeIntervalSince1970)
            .order(articlePublishedDate.desc)
        return try database.prepare(query).map(rowToArticle)
    }

    func undatedArticles(forFeedID fid: Int64) throws -> [Article] {
        let query = articles
            .filter(articleFeedID == fid && articlePublishedDate == nil)
            .order(articleID.desc)
        return try database.prepare(query).map(rowToArticle)
    }

    func earliestArticleDate(forFeedID fid: Int64, before date: Date) throws -> Date? {
        let query = articles
            .filter(articleFeedID == fid
                    && articlePublishedDate != nil
                    && articlePublishedDate < date.timeIntervalSince1970)
            .order(articlePublishedDate.desc)
            .limit(1)
        guard let row = try database.pluck(query),
              let timestamp = row[articlePublishedDate] else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    func earliestArticleDate(before date: Date) throws -> Date? {
        let query = articles
            .filter(articlePublishedDate != nil
                    && articlePublishedDate < date.timeIntervalSince1970)
            .order(articlePublishedDate.desc)
            .limit(1)
        guard let row = try database.pluck(query),
              let timestamp = row[articlePublishedDate] else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    func allArticles(limit: Int = 100) throws -> [Article] {
        let query = articles
            .order(articlePublishedDate.desc)
            .limit(limit)
        return try database.prepare(query).map(rowToArticle)
    }

    func allArticles(since date: Date, limit: Int? = 200) throws -> [Article] {
        var query = articles
            .filter(articlePublishedDate >= date.timeIntervalSince1970)
            .order(articlePublishedDate.desc)
        if let limit {
            query = query.limit(limit)
        }
        return try database.prepare(query).map(rowToArticle)
    }

    func allArticles(from startDate: Date, to endDate: Date, limit: Int = 200) throws -> [Article] {
        let query = articles
            .filter(articlePublishedDate >= startDate.timeIntervalSince1970
                    && articlePublishedDate < endDate.timeIntervalSince1970)
            .order(articlePublishedDate.desc)
            .limit(limit)
        return try database.prepare(query).map(rowToArticle)
    }

    func allArticles(before date: Date, limit: Int = 200) throws -> [Article] {
        let query = articles
            .filter(articlePublishedDate < date.timeIntervalSince1970 || articlePublishedDate == nil)
            .order(articlePublishedDate.desc)
            .limit(limit)
        return try database.prepare(query).map(rowToArticle)
    }

    func unreadArticles(limit: Int = 50) throws -> [Article] {
        let query = articles
            .filter(articleIsRead == false)
            .order(articlePublishedDate.desc)
            .limit(limit)
        return try database.prepare(query).map(rowToArticle)
    }

    func searchArticles(query: String) throws -> [Article] {
        let pattern = "%\(query)%"
        let query = articles
            .filter(articleTitle.like(pattern) ||
                    articleAuthor.like(pattern) ||
                    articleSummary.like(pattern))
            .order(articlePublishedDate.desc)
            .limit(200)
        return try database.prepare(query).map(rowToArticle)
    }

    func bookmarkedArticles() throws -> [Article] {
        let query = articles
            .filter(articleIsBookmarked == true)
            .order(articlePublishedDate.desc)
        return try database.prepare(query).map(rowToArticle)
    }

    func bookmarkedCount() throws -> Int {
        try database.scalar(articles.filter(articleIsBookmarked == true).count)
    }

    func markArticleRead(id: Int64, read: Bool) throws {
        let target = articles.filter(articleID == id)
        try database.run(target.update(articleIsRead <- read))
    }

    /// Batched counterpart of `markArticleRead(id:read:)` — applies a single
    /// `UPDATE ... WHERE id IN (...)` so N scroll-mark-as-read events collapse
    /// into one SQLite write instead of N.
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

    // MARK: - Recently Accessed

    func updateLastAccessed(articleID id: Int64) throws {
        let target = articles.filter(articleID == id)
        try database.run(target.update(articleLastAccessed <- Date().timeIntervalSince1970))
    }

    /// Batched counterpart of `updateLastAccessed(articleID:)` — stamps the
    /// same timestamp across all ids in one `UPDATE`.
    func updateLastAccessed(articleIDs ids: [Int64]) throws {
        guard !ids.isEmpty else { return }
        let target = articles.filter(ids.contains(articleID))
        try database.run(target.update(articleLastAccessed <- Date().timeIntervalSince1970))
    }

    func recentlyAccessedArticles(limit: Int = 20) throws -> [Article] {
        let query = articles
            .filter(articleLastAccessed != nil)
            .order(articleLastAccessed.desc)
            .limit(limit)
        return try database.prepare(query).map(rowToArticle)
    }

    func clearAccessHistory() throws {
        try database.run(articles.update(articleLastAccessed <- nil))
    }

    func articlesForEntity(name: String, types: [String], limit: Int = 10) throws -> [Article] {
        guard !types.isEmpty else { return [] }
        let placeholders = types.map { _ in "?" }.joined(separator: ", ")
        let sql = """
            SELECT DISTINCT a.*
            FROM nlp_entities ne
            JOIN articles a ON ne.article_id = a.id
            WHERE LOWER(ne.name) = LOWER(?)
              AND ne.type IN (\(placeholders))
            ORDER BY a.published_date DESC
            LIMIT ?
            """
        var bindings: [Binding?] = [name as Binding?]
        bindings.append(contentsOf: types.map { $0 as Binding? })
        bindings.append(limit)
        var results: [Article] = []
        let stmt = try database.prepare(sql, bindings)
        for row in stmt {
            // Map raw SQL row to Article manually
            guard let id = row[0] as? Int64,
                  let feedID = row[1] as? Int64,
                  let title = row[2] as? String,
                  let url = row[3] as? String else { continue }
            let carouselRaw = row[8] as? String
            let carouselURLs = carouselRaw?
                .split(separator: "\n")
                .map(String.init) ?? []
            results.append(Article(
                id: id,
                feedID: feedID,
                title: title,
                url: url,
                author: row[4] as? String,
                summary: row[5] as? String,
                content: row[6] as? String,
                imageURL: row[7] as? String,
                carouselImageURLs: carouselURLs,
                publishedDate: (row[9] as? Double).map { Date(timeIntervalSince1970: $0) },
                isRead: (row[10] as? Int64).map { $0 != 0 } ?? false,
                isBookmarked: (row[11] as? Int64).map { $0 != 0 } ?? false,
                audioURL: row[12] as? String,
                duration: (row[13] as? Int64).map { Int($0) }
            ))
        }
        return results
    }

    // MARK: - Cleanup

    func deleteArticles(olderThan date: Date) throws {
        let target = articles.filter(
            (articlePublishedDate < date.timeIntervalSince1970 || articlePublishedDate == nil)
                && articleIsBookmarked == false
        )
        try database.run(target.delete())
    }

    func deleteAllArticlesOnly() throws {
        try database.run(articles.filter(articleIsBookmarked == false).delete())
    }

    func vacuum() throws {
        try database.run("VACUUM")
    }

    // MARK: - Row Mapping

    func rowToArticle(_ row: Row) -> Article {
        let carouselRaw = row[articleCarouselURLs]
        let carouselURLs = carouselRaw?
            .split(separator: "\n")
            .map(String.init) ?? []
        return Article(
            id: row[articleID],
            feedID: row[articleFeedID],
            title: row[articleTitle],
            url: row[articleURL],
            author: row[articleAuthor],
            summary: row[articleSummary],
            content: row[articleContent],
            imageURL: row[articleImageURL],
            carouselImageURLs: carouselURLs,
            publishedDate: row[articlePublishedDate].map { Date(timeIntervalSince1970: $0) },
            isRead: row[articleIsRead],
            isBookmarked: row[articleIsBookmarked],
            audioURL: row[articleAudioURL],
            duration: row[articleDuration]
        )
    }
}
