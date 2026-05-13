import Foundation
@preconcurrency import SQLite

public nonisolated extension DatabaseManager {

    // MARK: - Feeds

    var feeds: Table { Table("feeds") }
    var feedID: SQLite.Expression<Int64> { SQLite.Expression<Int64>("id") }
    var feedTitle: SQLite.Expression<String> { SQLite.Expression<String>("title") }
    var feedURL: SQLite.Expression<String> { SQLite.Expression<String>("url") }
    var feedSiteURL: SQLite.Expression<String> { SQLite.Expression<String>("site_url") }
    var feedDescription: SQLite.Expression<String> { SQLite.Expression<String>("description") }
    var feedIconURL: SQLite.Expression<String?> { SQLite.Expression<String?>("favicon_url") }
    var feedLastFetched: SQLite.Expression<Double?> { SQLite.Expression<Double?>("last_fetched") }
    var feedCategory: SQLite.Expression<String?> { SQLite.Expression<String?>("category") }
    var feedIsPodcast: SQLite.Expression<Bool> { SQLite.Expression<Bool>("is_podcast") }
    var feedIsMuted: SQLite.Expression<Bool> { SQLite.Expression<Bool>("is_muted") }
    var feedCustomIconURL: SQLite.Expression<String?> { SQLite.Expression<String?>("custom_icon_url") }
    var feedAcronymIcon: SQLite.Expression<Data?> { SQLite.Expression<Data?>("acronym_icon") }
    var feedIsTitleCustomized: SQLite.Expression<Bool> { SQLite.Expression<Bool>("is_title_customized") }
    var feedIsFediverse: SQLite.Expression<Bool?> { SQLite.Expression<Bool?>("is_fediverse") }

    // MARK: - Articles

    var articles: Table { Table("articles") }
    var articleID: SQLite.Expression<Int64> { SQLite.Expression<Int64>("id") }
    var articleFeedID: SQLite.Expression<Int64> { SQLite.Expression<Int64>("feed_id") }
    var articleTitle: SQLite.Expression<String> { SQLite.Expression<String>("title") }
    var articleURL: SQLite.Expression<String> { SQLite.Expression<String>("url") }
    var articleAuthor: SQLite.Expression<String?> { SQLite.Expression<String?>("author") }
    var articleSummary: SQLite.Expression<String?> { SQLite.Expression<String?>("summary") }
    var articleContent: SQLite.Expression<String?> { SQLite.Expression<String?>("content") }
    var articleImageURL: SQLite.Expression<String?> { SQLite.Expression<String?>("image_url") }
    var articleCarouselURLs: SQLite.Expression<String?> { SQLite.Expression<String?>("carousel_urls") }
    var articlePublishedDate: SQLite.Expression<Double?> { SQLite.Expression<Double?>("published_date") }
    var articleIsRead: SQLite.Expression<Bool> { SQLite.Expression<Bool>("is_read") }
    var articleIsBookmarked: SQLite.Expression<Bool> { SQLite.Expression<Bool>("is_bookmarked") }
    var articleHasFullText: SQLite.Expression<Bool> { SQLite.Expression<Bool>("has_full_text") }
    var articleAudioURL: SQLite.Expression<String?> { SQLite.Expression<String?>("audio_url") }
    var articleDuration: SQLite.Expression<Int?> { SQLite.Expression<Int?>("duration") }
    var articleAISummary: SQLite.Expression<String?> { SQLite.Expression<String?>("ai_summary") }
    var articleTranslatedTitle: SQLite.Expression<String?> { SQLite.Expression<String?>("translated_title") }
    var articleTranslatedText: SQLite.Expression<String?> { SQLite.Expression<String?>("translated_text") }
    var articleTranslatedSummary: SQLite.Expression<String?> { SQLite.Expression<String?>("translated_summary") }
    var articleParserVersion: SQLite.Expression<Int> { SQLite.Expression<Int>("parser_version") }
    var articleSentimentScore: SQLite.Expression<Double?> { SQLite.Expression<Double?>("sentiment_score") }
    var articleSentimentProcessed: SQLite.Expression<Bool> { SQLite.Expression<Bool>("sentiment_processed") }
    var articleEntitiesProcessed: SQLite.Expression<Bool> { SQLite.Expression<Bool>("entities_processed") }
    var articleSimilarComputed: SQLite.Expression<Bool> { SQLite.Expression<Bool>("similar_computed") }
    var articleLastAccessed: SQLite.Expression<Double?> { SQLite.Expression<Double?>("last_accessed") }
    var articleDownloadPath: SQLite.Expression<String?> { SQLite.Expression<String?>("download_path") }
    var articleTranscriptJSON: SQLite.Expression<String?> { SQLite.Expression<String?>("transcript_json") }
    var articleCommentsFetchedAt: SQLite.Expression<Double?> { SQLite.Expression<Double?>("comments_fetched_at") }

    // MARK: - Comments

    var comments: Table { Table("comments") }
    var commentID: SQLite.Expression<Int64> { SQLite.Expression<Int64>("id") }
    var commentArticleID: SQLite.Expression<Int64> { SQLite.Expression<Int64>("article_id") }
    var commentRank: SQLite.Expression<Int> { SQLite.Expression<Int>("rank") }
    var commentAuthor: SQLite.Expression<String> { SQLite.Expression<String>("author") }
    var commentBody: SQLite.Expression<String> { SQLite.Expression<String>("body") }
    var commentCreatedDate: SQLite.Expression<Double?> { SQLite.Expression<Double?>("created_date") }
    var commentSourceURL: SQLite.Expression<String?> { SQLite.Expression<String?>("source_url") }

    // MARK: - NLP

    var nlpEntities: Table { Table("nlp_entities") }
    var nlpEntityID: SQLite.Expression<Int64> { SQLite.Expression<Int64>("id") }
    var nlpEntityArticleID: SQLite.Expression<Int64> { SQLite.Expression<Int64>("article_id") }
    var nlpEntityName: SQLite.Expression<String> { SQLite.Expression<String>("name") }
    var nlpEntityType: SQLite.Expression<String> { SQLite.Expression<String>("type") }

    var similarArticles: Table { Table("similar_articles") }
    var similarSourceID: SQLite.Expression<Int64> { SQLite.Expression<Int64>("source_id") }
    var similarTargetID: SQLite.Expression<Int64> { SQLite.Expression<Int64>("similar_id") }
    var similarDistance: SQLite.Expression<Double> { SQLite.Expression<Double>("distance") }
    var similarRank: SQLite.Expression<Int> { SQLite.Expression<Int>("rank") }

    // MARK: - Image Cache

    var imageCache: Table { Table("image_cache") }
    var imageCacheURL: SQLite.Expression<String> { SQLite.Expression<String>("url") }
    var imageCacheData: SQLite.Expression<Data> { SQLite.Expression<Data>("data") }
    var imageCachedAt: SQLite.Expression<Double> { SQLite.Expression<Double>("cached_at") }

    // MARK: - Summaries

    var summaryCache: Table { Table("summary_cache") }
    var summaryCacheType: SQLite.Expression<String> { SQLite.Expression<String>("type") }
    var summaryCacheDate: SQLite.Expression<String> { SQLite.Expression<String>("date") }
    var summaryCacheContent: SQLite.Expression<String> { SQLite.Expression<String>("content") }

    var summaryHeadlines: Table { Table("summary_headlines") }
    var summaryHeadlineType: SQLite.Expression<String> { SQLite.Expression<String>("type") }
    var summaryHeadlineDate: SQLite.Expression<String> { SQLite.Expression<String>("date") }
    var summaryHeadlineOrdinal: SQLite.Expression<Int> { SQLite.Expression<Int>("ordinal") }
    var summaryHeadlineText: SQLite.Expression<String> { SQLite.Expression<String>("headline") }
    var summaryHeadlineArticleIDs: SQLite.Expression<String> { SQLite.Expression<String>("article_ids") }
    var summaryHeadlineFeedIDs: SQLite.Expression<String> { SQLite.Expression<String>("feed_ids") }
    var summaryHeadlineThumbnailURL: SQLite.Expression<String?> { SQLite.Expression<String?>("thumbnail_url") }
    var summaryHeadlinePartialGeneration: SQLite.Expression<Bool> { SQLite.Expression<Bool>("partial_generation") }
    var summaryHeadlineArticleCountAtGeneration: SQLite.Expression<Int> {
        SQLite.Expression<Int>("article_count_at_generation")
    }

    // MARK: - Feed Rules

    var feedRules: Table { Table("feed_rules") }
    var ruleID: SQLite.Expression<Int64> { SQLite.Expression<Int64>("id") }
    var ruleFeedID: SQLite.Expression<Int64> { SQLite.Expression<Int64>("feed_id") }
    var ruleType: SQLite.Expression<String> { SQLite.Expression<String>("type") }
    var ruleValue: SQLite.Expression<String> { SQLite.Expression<String>("value") }

    // MARK: - Lists

    var lists: Table { Table("lists") }
    var listID: SQLite.Expression<Int64> { SQLite.Expression<Int64>("id") }
    var listName: SQLite.Expression<String> { SQLite.Expression<String>("name") }
    var listIcon: SQLite.Expression<String> { SQLite.Expression<String>("icon") }
    var listDisplayStyle: SQLite.Expression<String?> { SQLite.Expression<String?>("display_style") }
    var listSortOrder: SQLite.Expression<Int> { SQLite.Expression<Int>("sort_order") }

    var listFeeds: Table { Table("list_feeds") }
    var listFeedListID: SQLite.Expression<Int64> { SQLite.Expression<Int64>("list_id") }
    var listFeedFeedID: SQLite.Expression<Int64> { SQLite.Expression<Int64>("feed_id") }

    var listRules: Table { Table("list_rules") }
    var listRuleID: SQLite.Expression<Int64> { SQLite.Expression<Int64>("id") }
    var listRuleListID: SQLite.Expression<Int64> { SQLite.Expression<Int64>("list_id") }
    var listRuleType: SQLite.Expression<String> { SQLite.Expression<String>("type") }
    var listRuleValue: SQLite.Expression<String> { SQLite.Expression<String>("value") }

    // MARK: - Content Overrides

    var contentOverrides: Table { Table("content_overrides") }
    var coFeedID: SQLite.Expression<Int64> { SQLite.Expression<Int64>("feed_id") }
    var coEnabled: SQLite.Expression<Bool> { SQLite.Expression<Bool>("enabled") }
    var coTitleField: SQLite.Expression<String> { SQLite.Expression<String>("title_field") }
    var coBodyField: SQLite.Expression<String> { SQLite.Expression<String>("body_field") }
    var coAuthorField: SQLite.Expression<String> { SQLite.Expression<String>("author_field") }

    // MARK: - Feed Refresh Metrics

    var feedRefreshMetrics: Table { Table("feed_refresh_metrics") }
    var metricFeedID: SQLite.Expression<Int64> { SQLite.Expression<Int64>("feed_id") }
    var metricLastDurationMs: SQLite.Expression<Int> { SQLite.Expression<Int>("last_duration_ms") }
    var metricAverageDurationMs: SQLite.Expression<Double> { SQLite.Expression<Double>("avg_duration_ms") }
    var metricSampleCount: SQLite.Expression<Int> { SQLite.Expression<Int>("sample_count") }
    var metricLastRecordedAt: SQLite.Expression<Double> { SQLite.Expression<Double>("last_recorded_at") }
}
