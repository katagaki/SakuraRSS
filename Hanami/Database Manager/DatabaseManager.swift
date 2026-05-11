import Foundation
@preconcurrency import SQLite

public nonisolated final class DatabaseManager: @unchecked Sendable {

    public static let shared = DatabaseManager()

    public static let databasePath: String = {
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.SakuraRSS"
        )!
        return containerURL.appendingPathComponent("Sakura.feeds").path
    }()

    public private(set) var database: Connection
    private init() {
        do {
            database = try Connection(Self.databasePath)
            try Self.applyConnectionPragmas(database)
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
    public func reconnect() throws {
        database = try Connection(Self.databasePath)
        try Self.applyConnectionPragmas(database)
        try createTables()
    }

    /// Enables WAL mode and raises busy timeout so reads don't stall behind writes.
    private static func applyConnectionPragmas(_ connection: Connection) throws {
        try connection.run("PRAGMA journal_mode = WAL")
        try connection.run("PRAGMA synchronous = NORMAL")
        connection.busyTimeout = 5.0
    }

    private func invalidateStaleParserCache() {
        let key = "App.ParserVersion.HTMLContentExtractor"
        let stored = UserDefaults.standard.integer(forKey: key)
        if stored < ContentResolver.parserVersion {
            try? invalidateAllCachedArticleContent()
            UserDefaults.standard.set(ContentResolver.parserVersion, forKey: key)
        }
    }

    /// Collapses legacy intelligence toggles into `Intelligence.ContentInsights.Enabled`.
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

    /// Bumps the similar-content algorithm version and wipes the cache on upgrade.
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
        try createFeedsTable()
        try createArticlesTable()
        try database.run(articles.createIndex(articleFeedID, ifNotExists: true))
        try database.run(articles.createIndex(articlePublishedDate, ifNotExists: true))
        try database.run(articles.createIndex(articleFeedID, articleIsRead, ifNotExists: true))
        try createCommentsTable()
        try database.run(comments.createIndex(commentArticleID, ifNotExists: true))
    }

    private func createFeedsTable() throws {
        try database.run(feeds.create(ifNotExists: true) { table in
            table.column(feedID, primaryKey: .autoincrement)
            table.column(feedTitle)
            table.column(feedURL, unique: true)
            table.column(feedSiteURL)
            table.column(feedDescription, defaultValue: "")
            table.column(feedIconURL)
            table.column(feedLastFetched)
            table.column(feedCategory)
            table.column(feedIsPodcast, defaultValue: false)
            table.column(feedIsMuted, defaultValue: false)
            table.column(feedCustomIconURL)
            table.column(feedAcronymIcon)
            table.column(feedIsTitleCustomized, defaultValue: false)
            table.column(feedIsFediverse)
        })
    }

    private func createArticlesTable() throws {
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
            table.column(articleCommentsFetchedAt)
        })
    }

    private func createCommentsTable() throws {
        try database.run(comments.create(ifNotExists: true) { table in
            table.column(commentID, primaryKey: .autoincrement)
            table.column(commentArticleID, references: articles, articleID)
            table.column(commentRank, defaultValue: 0)
            table.column(commentAuthor, defaultValue: "")
            table.column(commentBody, defaultValue: "")
            table.column(commentCreatedDate)
            table.column(commentSourceURL)
        })
    }

    private func createAuxiliaryTables() throws {
        try createCacheTables()
        try createListsAndRulesTables()
        try createOverrideAndMetricsTables()
    }

    private func createCacheTables() throws {
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
        try database.run(summaryHeadlines.create(ifNotExists: true) { table in
            table.column(summaryHeadlineType)
            table.column(summaryHeadlineDate)
            table.column(summaryHeadlineOrdinal)
            table.column(summaryHeadlineText)
            table.column(summaryHeadlineArticleIDs)
            table.column(summaryHeadlineFeedIDs)
            table.column(summaryHeadlineThumbnailURL)
            table.column(summaryHeadlinePartialGeneration, defaultValue: false)
            table.column(summaryHeadlineArticleCountAtGeneration, defaultValue: 0)
            table.primaryKey(summaryHeadlineType, summaryHeadlineDate, summaryHeadlineOrdinal)
        })
    }

    private func createListsAndRulesTables() throws {
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

    private func createOverrideAndMetricsTables() throws {
        try database.run(contentOverrides.create(ifNotExists: true) { table in
            table.column(coFeedID, primaryKey: true, references: feeds, feedID)
            table.column(coEnabled, defaultValue: false)
            table.column(coTitleField, defaultValue: "default")
            table.column(coBodyField, defaultValue: "default")
            table.column(coAuthorField, defaultValue: "default")
        })
        try database.run(feedRefreshMetrics.create(ifNotExists: true) { table in
            table.column(metricFeedID, primaryKey: true, references: feeds, feedID)
            table.column(metricLastDurationMs, defaultValue: 0)
            table.column(metricAverageDurationMs, defaultValue: 0.0)
            table.column(metricSampleCount, defaultValue: 0)
            table.column(metricLastRecordedAt, defaultValue: 0.0)
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
