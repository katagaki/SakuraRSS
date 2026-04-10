import Foundation
@preconcurrency import SQLite

nonisolated extension DatabaseManager {

    func fixup() {
        // feeds table
        _ = try? database.run(feeds.addColumn(feedTitle, defaultValue: ""))
        _ = try? database.run(feeds.addColumn(feedURL, defaultValue: ""))
        _ = try? database.run(feeds.addColumn(feedSiteURL, defaultValue: ""))
        _ = try? database.run(feeds.addColumn(feedDescription, defaultValue: ""))
        _ = try? database.run(feeds.addColumn(feedFaviconURL))
        _ = try? database.run(feeds.addColumn(feedLastFetched))
        _ = try? database.run(feeds.addColumn(feedCategory))
        _ = try? database.run(feeds.addColumn(feedIsPodcast, defaultValue: false))
        _ = try? database.run(feeds.addColumn(feedIsMuted, defaultValue: false))
        _ = try? database.run(feeds.addColumn(feedCustomIconURL))
        _ = try? database.run(feeds.addColumn(feedAcronymIcon))

        // articles table
        _ = try? database.run(articles.addColumn(articleFeedID, defaultValue: 0))
        _ = try? database.run(articles.addColumn(articleTitle, defaultValue: ""))
        _ = try? database.run(articles.addColumn(articleURL, defaultValue: ""))
        _ = try? database.run(articles.addColumn(articleAuthor))
        _ = try? database.run(articles.addColumn(articleSummary))
        _ = try? database.run(articles.addColumn(articleContent))
        _ = try? database.run(articles.addColumn(articleImageURL))
        _ = try? database.run(articles.addColumn(articleCarouselURLs))
        _ = try? database.run(articles.addColumn(articlePublishedDate))
        _ = try? database.run(articles.addColumn(articleIsRead, defaultValue: false))
        _ = try? database.run(articles.addColumn(articleIsBookmarked, defaultValue: false))
        _ = try? database.run(articles.addColumn(articleHasFullText, defaultValue: false))
        _ = try? database.run(articles.addColumn(articleAudioURL))
        _ = try? database.run(articles.addColumn(articleDuration))
        _ = try? database.run(articles.addColumn(articleAISummary))
        _ = try? database.run(articles.addColumn(articleTranslatedTitle))
        _ = try? database.run(articles.addColumn(articleTranslatedText))
        _ = try? database.run(articles.addColumn(articleTranslatedSummary))
        _ = try? database.run(articles.addColumn(articleParserVersion, defaultValue: 0))

        // image_cache table
        _ = try? database.run(imageCache.addColumn(imageCacheData, defaultValue: Data()))
        _ = try? database.run(imageCache.addColumn(imageCachedAt, defaultValue: 0.0))

        // summary_cache table
        _ = try? database.run(summaryCache.addColumn(summaryCacheContent, defaultValue: ""))

        // feed_rules table
        _ = try? database.run(feedRules.addColumn(ruleFeedID, defaultValue: 0))
        _ = try? database.run(feedRules.addColumn(ruleType, defaultValue: ""))
        _ = try? database.run(feedRules.addColumn(ruleValue, defaultValue: ""))

        // Recreate indexes
        _ = try? database.run(articles.createIndex(articleFeedID, ifNotExists: true))
        _ = try? database.run(articles.createIndex(articlePublishedDate, ifNotExists: true))
        _ = try? database.run(articles.createIndex(articleFeedID, articleIsRead, ifNotExists: true))

        // lists table
        _ = try? database.run(lists.addColumn(listName, defaultValue: ""))
        _ = try? database.run(lists.addColumn(listIcon, defaultValue: "newspaper"))
        _ = try? database.run(lists.addColumn(listDisplayStyle))
        _ = try? database.run(lists.addColumn(listSortOrder, defaultValue: 0))

        // list_feeds table
        _ = try? database.run(listFeeds.addColumn(listFeedListID, defaultValue: 0))
        _ = try? database.run(listFeeds.addColumn(listFeedFeedID, defaultValue: 0))

        // list_rules table
        _ = try? database.run(listRules.addColumn(listRuleListID, defaultValue: 0))
        _ = try? database.run(listRules.addColumn(listRuleType, defaultValue: ""))
        _ = try? database.run(listRules.addColumn(listRuleValue, defaultValue: ""))

        // NLP columns on articles
        _ = try? database.run(articles.addColumn(articleSentimentScore))
        _ = try? database.run(articles.addColumn(articleSentimentProcessed, defaultValue: false))
        _ = try? database.run(articles.addColumn(articleEntitiesProcessed, defaultValue: false))
        _ = try? database.run(articles.addColumn(articleSimilarComputed, defaultValue: false))

        // Podcast download & transcription columns
        _ = try? database.run(articles.addColumn(articleDownloadPath))
        _ = try? database.run(articles.addColumn(articleTranscriptJSON))

        // nlp_entities table
        _ = try? database.run(nlpEntities.create(ifNotExists: true) { table in
            table.column(nlpEntityID, primaryKey: .autoincrement)
            table.column(nlpEntityArticleID, defaultValue: 0)
            table.column(nlpEntityName, defaultValue: "")
            table.column(nlpEntityType, defaultValue: "")
        })
        _ = try? database.run(nlpEntities.createIndex(nlpEntityArticleID, ifNotExists: true))
        _ = try? database.run(nlpEntities.createIndex(nlpEntityType, nlpEntityName, ifNotExists: true))

        // similar_articles table
        _ = try? database.run(similarArticles.create(ifNotExists: true) { table in
            table.column(similarSourceID, defaultValue: 0)
            table.column(similarTargetID, defaultValue: 0)
            table.column(similarDistance, defaultValue: 0.0)
            table.column(similarRank, defaultValue: 0)
            table.primaryKey(similarSourceID, similarTargetID)
        })
        _ = try? database.run(similarArticles.createIndex(similarSourceID, ifNotExists: true))
    }
}
