import Foundation
@preconcurrency import SQLite

nonisolated final class DatabaseManager: @unchecked Sendable {

    static let shared = DatabaseManager()

    let database: Connection

    // MARK: - Tables

    let feeds = Table("feeds")
    let feedID = SQLite.Expression<Int64>("id")
    let feedTitle = SQLite.Expression<String>("title")
    let feedURL = SQLite.Expression<String>("url")
    let feedSiteURL = SQLite.Expression<String>("site_url")
    let feedDescription = SQLite.Expression<String>("description")
    let feedFaviconURL = SQLite.Expression<String?>("favicon_url")
    let feedLastFetched = SQLite.Expression<Double?>("last_fetched")
    let feedCategory = SQLite.Expression<String?>("category")
    let feedIsPodcast = SQLite.Expression<Bool>("is_podcast")
    let feedIsMuted = SQLite.Expression<Bool>("is_muted")
    let feedCustomIconURL = SQLite.Expression<String?>("custom_icon_url")
    let feedAcronymIcon = SQLite.Expression<Data?>("acronym_icon")

    let imageCache = Table("image_cache")
    let imageCacheURL = SQLite.Expression<String>("url")
    let imageCacheData = SQLite.Expression<Data>("data")
    let imageCachedAt = SQLite.Expression<Double>("cached_at")

    let articles = Table("articles")
    let articleID = SQLite.Expression<Int64>("id")
    let articleFeedID = SQLite.Expression<Int64>("feed_id")
    let articleTitle = SQLite.Expression<String>("title")
    let articleURL = SQLite.Expression<String>("url")
    let articleAuthor = SQLite.Expression<String?>("author")
    let articleSummary = SQLite.Expression<String?>("summary")
    let articleContent = SQLite.Expression<String?>("content")
    let articleImageURL = SQLite.Expression<String?>("image_url")
    let articlePublishedDate = SQLite.Expression<Double?>("published_date")
    let articleIsRead = SQLite.Expression<Bool>("is_read")
    let articleIsBookmarked = SQLite.Expression<Bool>("is_bookmarked")
    let articleHasFullText = SQLite.Expression<Bool>("has_full_text")
    let articleAudioURL = SQLite.Expression<String?>("audio_url")
    let articleDuration = SQLite.Expression<Int?>("duration")
    let articleAISummary = SQLite.Expression<String?>("ai_summary")

    let summaryCache = Table("summary_cache")
    let summaryCacheType = SQLite.Expression<String>("type")
    let summaryCacheDate = SQLite.Expression<String>("date")
    let summaryCacheContent = SQLite.Expression<String>("content")

    let feedRules = Table("feed_rules")
    let ruleID = SQLite.Expression<Int64>("id")
    let ruleFeedID = SQLite.Expression<Int64>("feed_id")
    let ruleType = SQLite.Expression<String>("type")
    let ruleValue = SQLite.Expression<String>("value")

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
            table.column(feedIsPodcast, defaultValue: false)
            table.column(feedIsMuted, defaultValue: false)
            table.column(feedCustomIconURL)
            table.column(feedAcronymIcon)
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
            table.column(articleHasFullText, defaultValue: false)
            table.column(articleAudioURL)
            table.column(articleDuration)
            table.column(articleAISummary)
        })

        try database.run(articles.createIndex(articleFeedID, ifNotExists: true))
        try database.run(articles.createIndex(articlePublishedDate, ifNotExists: true))

        try database.run(imageCache.create(ifNotExists: true) { table in
            table.column(imageCacheURL, primaryKey: true)
            table.column(imageCacheData)
            table.column(imageCachedAt)
        })

        try database.run(summaryCache.create(ifNotExists: true) { table in
            table.column(summaryCacheType)
            table.column(summaryCacheDate)
            table.column(summaryCacheContent)
            table.primaryKey(summaryCacheType, summaryCacheDate)
        })

        try database.run(feedRules.create(ifNotExists: true) { table in
            table.column(ruleID, primaryKey: .autoincrement)
            table.column(ruleFeedID, references: feeds, feedID)
            table.column(ruleType)
            table.column(ruleValue)
        })

        // Migrations for columns added after initial release
        addColumnIfMissing(table: "feeds", column: "acronym_icon", type: "BLOB")
    }

    private func addColumnIfMissing(table: String, column: String, type: String) {
        let columns = (try? database.prepare("PRAGMA table_info(\(table))")) ?? AnySequence([])
        let columnNames = columns.compactMap { row -> String? in
            row[1] as? String
        }
        if !columnNames.contains(column) {
            _ = try? database.run("ALTER TABLE \(table) ADD COLUMN \(column) \(type)")
        }
    }
}
