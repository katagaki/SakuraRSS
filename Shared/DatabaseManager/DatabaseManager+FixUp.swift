import Foundation
@preconcurrency import SQLite

nonisolated extension DatabaseManager {

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
        try? database.run(articles.addColumn(articleTranslatedSummary))

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
}
