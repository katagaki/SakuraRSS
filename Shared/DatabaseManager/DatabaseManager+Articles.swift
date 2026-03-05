import Foundation
@preconcurrency import SQLite

/// Groups optional article fields to keep the insert call under the parameter limit.
struct ArticleInsertData {
    var author: String?
    var summary: String?
    var content: String?
    var imageURL: String?
    var publishedDate: Date?
    var audioURL: String?
    var duration: Int?
}

nonisolated extension DatabaseManager {

    // MARK: - Article CRUD

    @discardableResult
    func insertArticle(feedID fid: Int64, title: String, url: String,
                       data: ArticleInsertData = ArticleInsertData()) throws -> Int64 {
        try database.run(articles.insert(or: .ignore,
            articleFeedID <- fid,
            articleTitle <- title,
            articleURL <- url,
            articleAuthor <- data.author,
            articleSummary <- data.summary,
            articleContent <- data.content,
            articleImageURL <- data.imageURL,
            articlePublishedDate <- data.publishedDate?.timeIntervalSince1970,
            articleIsRead <- false,
            articleIsBookmarked <- false,
            articleAudioURL <- data.audioURL,
            articleDuration <- data.duration
        ))
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

    // MARK: - Row Mapping

    func rowToArticle(_ row: Row) -> Article {
        Article(
            id: row[articleID],
            feedID: row[articleFeedID],
            title: row[articleTitle],
            url: row[articleURL],
            author: row[articleAuthor],
            summary: row[articleSummary],
            content: row[articleContent],
            imageURL: row[articleImageURL],
            publishedDate: row[articlePublishedDate].map { Date(timeIntervalSince1970: $0) },
            isRead: row[articleIsRead],
            isBookmarked: row[articleIsBookmarked],
            audioURL: row[articleAudioURL],
            duration: row[articleDuration]
        )
    }
}
