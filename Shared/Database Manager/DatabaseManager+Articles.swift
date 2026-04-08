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

    func insertArticles(feedID fid: Int64, articles items: [ArticleInsertItem]) throws {
        guard !items.isEmpty else { return }
        let cutoffTimestamp = UserDefaults.standard.double(forKey: "Content.CutoffDate")
        let cutoffDate: Date? = cutoffTimestamp > 0
            ? Date(timeIntervalSince1970: cutoffTimestamp) : nil
        try database.transaction {
            for item in items {
                if let cutoff = cutoffDate, let published = item.data.publishedDate,
                   published < cutoff {
                    continue
                }
                let carouselValue = item.data.carouselImageURLs.isEmpty
                    ? nil : item.data.carouselImageURLs.joined(separator: "\n")
                try database.run(articles.insert(or: .ignore,
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
            }
        }
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

    func allArticles(limit: Int = 100) throws -> [Article] {
        let query = articles
            .order(articlePublishedDate.desc)
            .limit(limit)
        return try database.prepare(query).map(rowToArticle)
    }

    func allArticles(since date: Date, limit: Int = 200) throws -> [Article] {
        let query = articles
            .filter(articlePublishedDate >= date.timeIntervalSince1970)
            .order(articlePublishedDate.desc)
            .limit(limit)
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

    func markArticleRead(id: Int64, read: Bool) throws {
        let target = articles.filter(articleID == id)
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
