import Foundation
@preconcurrency import SQLite

nonisolated extension DatabaseManager {

    func createTables() throws {
        try createCoreTables()
        try createAuxiliaryTables()
        try createNLPTables()
        try createSyncTables()
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
            table.column(feedSyncID)
            table.column(feedUserModifiedAt)
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
            table.column(articleExternalSource, defaultValue: false)
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
        try createBookmarkFolderTables()
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

    private func createBookmarkFolderTables() throws {
        try database.run(bookmarkFolders.create(ifNotExists: true) { table in
            table.column(bookmarkFolderID, primaryKey: .autoincrement)
            table.column(bookmarkFolderName)
            table.column(bookmarkFolderIcon, defaultValue: "bookmark")
            table.column(bookmarkFolderDisplayStyle)
            table.column(bookmarkFolderSortOrder, defaultValue: 0)
            table.column(bookmarkFolderParentID)
        })
        try database.run(bookmarkFolderItems.create(ifNotExists: true) { table in
            table.column(bookmarkFolderItemFolderID)
            table.column(bookmarkFolderItemArticleID)
            table.primaryKey(bookmarkFolderItemFolderID, bookmarkFolderItemArticleID)
        })
        try database.run(bookmarkFolderItems.createIndex(bookmarkFolderItemArticleID, ifNotExists: true))
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
