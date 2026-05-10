import Foundation
@preconcurrency import SQLite

public nonisolated extension DatabaseManager {

    // MARK: - Full Article Text Cache

    func cachedArticleContent(for articleId: Int64) throws -> String? {
        let query = articles.filter(
            articleID == articleId
                && articleHasFullText == true
                && articleParserVersion == ContentResolver.parserVersion
        )
        guard let row = try database.pluck(query) else { return nil }
        return row[articleContent]
    }

    func cacheArticleContent(_ content: String, for articleId: Int64) throws {
        let target = articles.filter(articleID == articleId)
        try database.run(target.update(
            articleContent <- content,
            articleHasFullText <- true,
            articleParserVersion <- ContentResolver.parserVersion
        ))
    }

    func clearCachedArticleContent(for articleId: Int64) throws {
        let target = articles.filter(articleID == articleId)
        try database.run(target.update(
            articleContent <- nil,
            articleHasFullText <- false
        ))
    }

    func invalidateAllCachedArticleContent() throws {
        let stale = articles.filter(articleHasFullText == true && articleIsBookmarked == false)
        try database.run(stale.update(articleHasFullText <- false))
    }

    // MARK: - AI Summary Cache

    func cachedArticleSummary(for articleId: Int64) throws -> String? {
        let query = articles.filter(articleID == articleId)
        guard let row = try database.pluck(query) else { return nil }
        return row[articleAISummary]
    }

    func cacheArticleSummary(_ summary: String, for articleId: Int64) throws {
        let target = articles.filter(articleID == articleId)
        try database.run(target.update(articleAISummary <- summary))
    }

    func clearCachedArticleSummary(for articleId: Int64) throws {
        let target = articles.filter(articleID == articleId)
        try database.run(target.update(articleAISummary <- nil))
    }

    // MARK: - Translation Cache

    func cachedArticleTranslation(
        for articleId: Int64
    ) throws -> CachedArticleTranslation? {
        let query = articles.filter(articleID == articleId)
        guard let row = try database.pluck(query) else { return nil }
        let title = row[articleTranslatedTitle]
        let text = row[articleTranslatedText]
        let summary = row[articleTranslatedSummary]
        guard title != nil || text != nil || summary != nil else { return nil }
        return CachedArticleTranslation(title: title, text: text, summary: summary)
    }

    func cacheArticleTranslation(
        title: String?, text: String?, for articleId: Int64
    ) throws {
        let target = articles.filter(articleID == articleId)
        try database.run(target.update(
            articleTranslatedTitle <- title,
            articleTranslatedText <- text
        ))
    }

    func cacheTranslatedSummary(_ summary: String, for articleId: Int64) throws {
        let target = articles.filter(articleID == articleId)
        try database.run(target.update(articleTranslatedSummary <- summary))
    }

    func clearCachedArticleTranslation(for articleId: Int64) throws {
        let target = articles.filter(articleID == articleId)
        try database.run(target.update(
            articleTranslatedTitle <- nil,
            articleTranslatedText <- nil,
            articleTranslatedSummary <- nil
        ))
    }
}
