import Foundation
@preconcurrency import SQLite

nonisolated final class DatabaseManager: @unchecked Sendable {

    static let shared = DatabaseManager()

    private let database: Connection

    // MARK: - Tables

    private let feeds = Table("feeds")
    private let feedID = SQLite.Expression<Int64>("id")
    private let feedTitle = SQLite.Expression<String>("title")
    private let feedURL = SQLite.Expression<String>("url")
    private let feedSiteURL = SQLite.Expression<String>("site_url")
    private let feedDescription = SQLite.Expression<String>("description")
    private let feedFaviconURL = SQLite.Expression<String?>("favicon_url")
    private let feedLastFetched = SQLite.Expression<Double?>("last_fetched")
    private let feedCategory = SQLite.Expression<String?>("category")

    private let articles = Table("articles")
    private let articleID = SQLite.Expression<Int64>("id")
    private let articleFeedID = SQLite.Expression<Int64>("feed_id")
    private let articleTitle = SQLite.Expression<String>("title")
    private let articleURL = SQLite.Expression<String>("url")
    private let articleAuthor = SQLite.Expression<String?>("author")
    private let articleSummary = SQLite.Expression<String?>("summary")
    private let articleContent = SQLite.Expression<String?>("content")
    private let articleImageURL = SQLite.Expression<String?>("image_url")
    private let articlePublishedDate = SQLite.Expression<Double?>("published_date")
    private let articleIsRead = SQLite.Expression<Bool>("is_read")
    private let articleIsBookmarked = SQLite.Expression<Bool>("is_bookmarked")

    // MARK: - Init

    private init() {
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.SakuraRSS"
        )!
        let dbPath = containerURL.appendingPathComponent("Sakura.feeds").path
        do {
            database = try Connection(dbPath)
            try createTables()
        } catch {
            fatalError("Database initialization failed: \(error)")
        }
    }

    private func createTables() throws {
        try database.run(feeds.create(ifNotExists: true) { table in
            table.column(feedID, primaryKey: .autoincrement)
            table.column(feedTitle)
            table.column(feedURL, unique: true)
            table.column(feedSiteURL)
            table.column(feedDescription, defaultValue: "")
            table.column(feedFaviconURL)
            table.column(feedLastFetched)
            table.column(feedCategory)
        })

        try database.run(articles.create(ifNotExists: true) { table in
            table.column(articleID, primaryKey: .autoincrement)
            table.column(articleFeedID, references: feeds, feedID)
            table.column(articleTitle)
            table.column(articleURL, unique: true)
            table.column(articleAuthor)
            table.column(articleSummary)
            table.column(articleContent)
            table.column(articleImageURL)
            table.column(articlePublishedDate)
            table.column(articleIsRead, defaultValue: false)
            table.column(articleIsBookmarked, defaultValue: false)
        })

        try database.run(articles.createIndex(articleFeedID, ifNotExists: true))
        try database.run(articles.createIndex(articlePublishedDate, ifNotExists: true))
    }

    // MARK: - Feed CRUD

    @discardableResult
    func insertFeed(title: String, url: String, siteURL: String,
                    description: String = "", faviconURL: String? = nil,
                    category: String? = nil) throws -> Int64 {
        try database.run(feeds.insert(
            feedTitle <- title,
            feedURL <- url,
            feedSiteURL <- siteURL,
            feedDescription <- description,
            feedFaviconURL <- faviconURL,
            feedCategory <- category
        ))
    }

    func allFeeds() throws -> [Feed] {
        try database.prepare(feeds.order(feedTitle.asc)).map { row in
            Feed(
                id: row[feedID],
                title: row[feedTitle],
                url: row[feedURL],
                siteURL: row[feedSiteURL],
                feedDescription: row[feedDescription],
                faviconURL: row[feedFaviconURL],
                lastFetched: row[feedLastFetched].map { Date(timeIntervalSince1970: $0) },
                category: row[feedCategory]
            )
        }
    }

    func feed(byID id: Int64) throws -> Feed? {
        guard let row = try database.pluck(feeds.filter(feedID == id)) else { return nil }
        return Feed(
            id: row[feedID],
            title: row[feedTitle],
            url: row[feedURL],
            siteURL: row[feedSiteURL],
            feedDescription: row[feedDescription],
            faviconURL: row[feedFaviconURL],
            lastFetched: row[feedLastFetched].map { Date(timeIntervalSince1970: $0) },
            category: row[feedCategory]
        )
    }

    func feed(byURL url: String) throws -> Feed? {
        guard let row = try database.pluck(feeds.filter(feedURL == url)) else { return nil }
        return Feed(
            id: row[feedID],
            title: row[feedTitle],
            url: row[feedURL],
            siteURL: row[feedSiteURL],
            feedDescription: row[feedDescription],
            faviconURL: row[feedFaviconURL],
            lastFetched: row[feedLastFetched].map { Date(timeIntervalSince1970: $0) },
            category: row[feedCategory]
        )
    }

    func updateFeedLastFetched(id: Int64, date: Date) throws {
        let target = feeds.filter(feedID == id)
        try database.run(target.update(feedLastFetched <- date.timeIntervalSince1970))
    }

    func updateFeed(id: Int64, title: String, category: String?) throws {
        let target = feeds.filter(feedID == id)
        try database.run(target.update(
            feedTitle <- title,
            feedCategory <- category
        ))
    }

    func deleteFeed(id: Int64) throws {
        try database.run(articles.filter(articleFeedID == id).delete())
        try database.run(feeds.filter(feedID == id).delete())
    }

    // MARK: - Article CRUD

    @discardableResult
    func insertArticle(feedID fid: Int64, title: String, url: String,
                       author: String? = nil, summary: String? = nil,
                       content: String? = nil, imageURL: String? = nil,
                       publishedDate: Date? = nil) throws -> Int64 {
        try database.run(articles.insert(or: .ignore,
            articleFeedID <- fid,
            articleTitle <- title,
            articleURL <- url,
            articleAuthor <- author,
            articleSummary <- summary,
            articleContent <- content,
            articleImageURL <- imageURL,
            articlePublishedDate <- publishedDate?.timeIntervalSince1970,
            articleIsRead <- false,
            articleIsBookmarked <- false
        ))
    }

    func articles(forFeedID fid: Int64) throws -> [Article] {
        let query = articles
            .filter(articleFeedID == fid)
            .order(articlePublishedDate.desc)
        return try database.prepare(query).map(rowToArticle)
    }

    func allArticles(limit: Int = 100) throws -> [Article] {
        let query = articles
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

    // MARK: - Helpers

    private func rowToArticle(_ row: Row) -> Article {
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
            isBookmarked: row[articleIsBookmarked]
        )
    }
}
