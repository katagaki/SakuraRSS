import Foundation
@preconcurrency import SQLite

nonisolated final class DatabaseManager: @unchecked Sendable {

    static let shared = DatabaseManager()

    static let databasePath: String = {
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.SakuraRSS"
        )!
        return containerURL.appendingPathComponent("Sakura.feeds").path
    }()

    private(set) var database: Connection

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
    let feedIsTitleCustomized = SQLite.Expression<Bool>("is_title_customized")

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
    let articleCarouselURLs = SQLite.Expression<String?>("carousel_urls")
    let articlePublishedDate = SQLite.Expression<Double?>("published_date")
    let articleIsRead = SQLite.Expression<Bool>("is_read")
    let articleIsBookmarked = SQLite.Expression<Bool>("is_bookmarked")
    let articleHasFullText = SQLite.Expression<Bool>("has_full_text")
    let articleAudioURL = SQLite.Expression<String?>("audio_url")
    let articleDuration = SQLite.Expression<Int?>("duration")
    let articleAISummary = SQLite.Expression<String?>("ai_summary")
    let articleTranslatedTitle = SQLite.Expression<String?>("translated_title")
    let articleTranslatedText = SQLite.Expression<String?>("translated_text")
    let articleTranslatedSummary = SQLite.Expression<String?>("translated_summary")
    let articleParserVersion = SQLite.Expression<Int>("parser_version")
    let articleSentimentScore = SQLite.Expression<Double?>("sentiment_score")
    let articleSentimentProcessed = SQLite.Expression<Bool>("sentiment_processed")
    let articleEntitiesProcessed = SQLite.Expression<Bool>("entities_processed")
    let articleSimilarComputed = SQLite.Expression<Bool>("similar_computed")
    let articleLastAccessed = SQLite.Expression<Double?>("last_accessed")
    let articleDownloadPath = SQLite.Expression<String?>("download_path")
    let articleTranscriptJSON = SQLite.Expression<String?>("transcript_json")

    let nlpEntities = Table("nlp_entities")
    let nlpEntityID = SQLite.Expression<Int64>("id")
    let nlpEntityArticleID = SQLite.Expression<Int64>("article_id")
    let nlpEntityName = SQLite.Expression<String>("name")
    let nlpEntityType = SQLite.Expression<String>("type")

    let similarArticles = Table("similar_articles")
    let similarSourceID = SQLite.Expression<Int64>("source_id")
    let similarTargetID = SQLite.Expression<Int64>("similar_id")
    let similarDistance = SQLite.Expression<Double>("distance")
    let similarRank = SQLite.Expression<Int>("rank")

    let summaryCache = Table("summary_cache")
    let summaryCacheType = SQLite.Expression<String>("type")
    let summaryCacheDate = SQLite.Expression<String>("date")
    let summaryCacheContent = SQLite.Expression<String>("content")

    let feedRules = Table("feed_rules")
    let ruleID = SQLite.Expression<Int64>("id")
    let ruleFeedID = SQLite.Expression<Int64>("feed_id")
    let ruleType = SQLite.Expression<String>("type")
    let ruleValue = SQLite.Expression<String>("value")

    let lists = Table("lists")
    let listID = SQLite.Expression<Int64>("id")
    let listName = SQLite.Expression<String>("name")
    let listIcon = SQLite.Expression<String>("icon")
    let listDisplayStyle = SQLite.Expression<String?>("display_style")
    let listSortOrder = SQLite.Expression<Int>("sort_order")

    let listFeeds = Table("list_feeds")
    let listFeedListID = SQLite.Expression<Int64>("list_id")
    let listFeedFeedID = SQLite.Expression<Int64>("feed_id")

    let listRules = Table("list_rules")
    let listRuleID = SQLite.Expression<Int64>("id")
    let listRuleListID = SQLite.Expression<Int64>("list_id")
    let listRuleType = SQLite.Expression<String>("type")
    let listRuleValue = SQLite.Expression<String>("value")

    // MARK: - Init

    private init() {
        do {
            database = try Connection(Self.databasePath)
            try createTables()
            fixupIfVersionChanged()
            invalidateStaleParserCache()
            migrateContentInsightsToggle()
            invalidateStaleSimilarContentCache()
        } catch {
            fatalError("Database initialization failed: \(error)")
        }
    }

    /// Replaces the current database connection and re-creates tables.
    /// Used after restoring a backup file to the database path.
    func reconnect() throws {
        database = try Connection(Self.databasePath)
        try createTables()
    }

    private func invalidateStaleParserCache() {
        let key = "App.ParserVersion.ArticleExtractor"
        let stored = UserDefaults.standard.integer(forKey: key)
        if stored < ParserVersion.articleExtractor {
            try? invalidateAllCachedArticleContent()
            UserDefaults.standard.set(ParserVersion.articleExtractor, forKey: key)
        }
    }

    /// Collapses the legacy `Intelligence.SimilarContent.Enabled` /
    /// `Intelligence.TopicsPeople.Enabled` toggles into a single
    /// `Intelligence.ContentInsights.Enabled` key. Runs exactly once per
    /// install, tracked by `Intelligence.ContentInsights.Migrated`.
    private func migrateContentInsightsToggle() {
        let defaults = UserDefaults.standard
        let migratedKey = "Intelligence.ContentInsights.Migrated"
        guard !defaults.bool(forKey: migratedKey) else { return }
        let legacySimilar = defaults.bool(forKey: "Intelligence.SimilarContent.Enabled")
        let legacyTopics = defaults.bool(forKey: "Intelligence.TopicsPeople.Enabled")
        if legacySimilar || legacyTopics {
            defaults.set(true, forKey: "Intelligence.ContentInsights.Enabled")
        }
        defaults.removeObject(forKey: "Intelligence.SimilarContent.Enabled")
        defaults.removeObject(forKey: "Intelligence.TopicsPeople.Enabled")
        defaults.set(true, forKey: migratedKey)
    }

    /// Bumps the similar-content algorithm version and wipes the cache the
    /// first time the app launches under a newer ranker. Deferred to a
    /// background task so the rewrite (which scans every article row)
    /// doesn't block the DB connection during cold launch — the old
    /// v1 rankings stay visible to the user for a few seconds longer,
    /// which is better than a frozen first-launch screen.  The version
    /// stamp is written eagerly so a crash between the bump and the
    /// wipe still lets the next launch finish the job.
    private func invalidateStaleSimilarContentCache() {
        let key = "Intelligence.SimilarContent.AlgorithmVersion"
        let current = 2   // v1: embedding-only; v2: hybrid embedding + entity Jaccard
        let stored = UserDefaults.standard.integer(forKey: key)
        guard stored < current else { return }
        UserDefaults.standard.set(current, forKey: key)
        Task.detached(priority: .utility) { [weak self] in
            try? self?.invalidateSimilarContentCache()
        }
    }

    private func fixupIfVersionChanged() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        let current = "\(version).\(build)"
        let stored = UserDefaults.standard.string(forKey: "App.DatabaseVersion")
        if current != stored {
            fixup()
            UserDefaults.standard.set(current, forKey: "App.DatabaseVersion")
        }
    }

    // MARK: - Tables

    private func createTables() throws {
        try createCoreTables()
        try createAuxiliaryTables()
        try createNLPTables()
    }

    private func createCoreTables() throws {
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
            table.column(feedIsTitleCustomized, defaultValue: false)
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
            table.column(articleCarouselURLs)
            table.column(articlePublishedDate)
            table.column(articleIsRead, defaultValue: false)
            table.column(articleIsBookmarked, defaultValue: false)
            table.column(articleHasFullText, defaultValue: false)
            table.column(articleAudioURL)
            table.column(articleDuration)
            table.column(articleAISummary)
            table.column(articleTranslatedTitle)
            table.column(articleTranslatedText)
            table.column(articleTranslatedSummary)
            table.column(articleParserVersion, defaultValue: 0)
            table.column(articleSentimentScore)
            table.column(articleSentimentProcessed, defaultValue: false)
            table.column(articleEntitiesProcessed, defaultValue: false)
            table.column(articleSimilarComputed, defaultValue: false)
            table.column(articleDownloadPath)
            table.column(articleTranscriptJSON)
        })

        try database.run(articles.createIndex(articleFeedID, ifNotExists: true))
        try database.run(articles.createIndex(articlePublishedDate, ifNotExists: true))
        try database.run(articles.createIndex(articleFeedID, articleIsRead, ifNotExists: true))
    }

    private func createAuxiliaryTables() throws {
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

        try database.run(lists.create(ifNotExists: true) { table in
            table.column(listID, primaryKey: .autoincrement)
            table.column(listName)
            table.column(listIcon, defaultValue: "newspaper")
            table.column(listDisplayStyle)
            table.column(listSortOrder, defaultValue: 0)
        })

        try database.run(listFeeds.create(ifNotExists: true) { table in
            table.column(listFeedListID)
            table.column(listFeedFeedID)
            table.primaryKey(listFeedListID, listFeedFeedID)
        })

        try database.run(listRules.create(ifNotExists: true) { table in
            table.column(listRuleID, primaryKey: .autoincrement)
            table.column(listRuleListID)
            table.column(listRuleType)
            table.column(listRuleValue)
        })
    }

    private func createNLPTables() throws {
        try database.run(nlpEntities.create(ifNotExists: true) { table in
            table.column(nlpEntityID, primaryKey: .autoincrement)
            table.column(nlpEntityArticleID, references: articles, articleID)
            table.column(nlpEntityName)
            table.column(nlpEntityType)
        })
        try database.run(nlpEntities.createIndex(nlpEntityArticleID, ifNotExists: true))
        try database.run(nlpEntities.createIndex(nlpEntityType, nlpEntityName, ifNotExists: true))

        try database.run(similarArticles.create(ifNotExists: true) { table in
            table.column(similarSourceID, references: articles, articleID)
            table.column(similarTargetID, references: articles, articleID)
            table.column(similarDistance)
            table.column(similarRank)
            table.primaryKey(similarSourceID, similarTargetID)
        })
        try database.run(similarArticles.createIndex(similarSourceID, ifNotExists: true))
    }
}
