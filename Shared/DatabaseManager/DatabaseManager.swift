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
    let articleTranslatedTitle = SQLite.Expression<String?>("translated_title")
    let articleTranslatedText = SQLite.Expression<String?>("translated_text")

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

    // MARK: - Fixup

    func fixup() {
        // feeds table
        try? database.run(feeds.addColumn(feedTitle, defaultValue: ""))
        try? database.run(feeds.addColumn(feedURL, defaultValue: ""))
        try? database.run(feeds.addColumn(feedSiteURL, defaultValue: ""))
        try? database.run(feeds.addColumn(feedDescription, defaultValue: ""))
        try? database.run(feeds.addColumn(feedFaviconURL))
        try? database.run(feeds.addColumn(feedLastFetched))
        try? database.run(feeds.addColumn(feedCategory))
        try? database.run(feeds.addColumn(feedIsPodcast, defaultValue: false))
        try? database.run(feeds.addColumn(feedIsMuted, defaultValue: false))
        try? database.run(feeds.addColumn(feedCustomIconURL))
        try? database.run(feeds.addColumn(feedAcronymIcon))

        // articles table
        try? database.run(articles.addColumn(articleFeedID, defaultValue: 0))
        try? database.run(articles.addColumn(articleTitle, defaultValue: ""))
        try? database.run(articles.addColumn(articleURL, defaultValue: ""))
        try? database.run(articles.addColumn(articleAuthor))
        try? database.run(articles.addColumn(articleSummary))
        try? database.run(articles.addColumn(articleContent))
        try? database.run(articles.addColumn(articleImageURL))
        try? database.run(articles.addColumn(articlePublishedDate))
        try? database.run(articles.addColumn(articleIsRead, defaultValue: false))
        try? database.run(articles.addColumn(articleIsBookmarked, defaultValue: false))
        try? database.run(articles.addColumn(articleHasFullText, defaultValue: false))
        try? database.run(articles.addColumn(articleAudioURL))
        try? database.run(articles.addColumn(articleDuration))
        try? database.run(articles.addColumn(articleAISummary))
        try? database.run(articles.addColumn(articleTranslatedTitle))
        try? database.run(articles.addColumn(articleTranslatedText))

        // image_cache table
        try? database.run(imageCache.addColumn(imageCacheData, defaultValue: Data()))
        try? database.run(imageCache.addColumn(imageCachedAt, defaultValue: 0.0))

        // summary_cache table
        try? database.run(summaryCache.addColumn(summaryCacheContent, defaultValue: ""))

        // feed_rules table
        try? database.run(feedRules.addColumn(ruleFeedID, defaultValue: 0))
        try? database.run(feedRules.addColumn(ruleType, defaultValue: ""))
        try? database.run(feedRules.addColumn(ruleValue, defaultValue: ""))

        // Recreate indexes
        try? database.run(articles.createIndex(articleFeedID, ifNotExists: true))
        try? database.run(articles.createIndex(articlePublishedDate, ifNotExists: true))
    }

    // MARK: - Tables

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
            table.column(articleTranslatedTitle)
            table.column(articleTranslatedText)
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
    }
}
