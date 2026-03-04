import Foundation
@preconcurrency import SQLite

nonisolated extension DatabaseManager {

    // MARK: - Full Article Text Cache

    func cachedArticleContent(for articleId: Int64) throws -> String? {
        let query = articles.filter(articleID == articleId && articleHasFullText == true)
        guard let row = try database.pluck(query) else { return nil }
        return row[articleContent]
    }

    func cacheArticleContent(_ content: String, for articleId: Int64) throws {
        let target = articles.filter(articleID == articleId)
        try database.run(target.update(
            articleContent <- content,
            articleHasFullText <- true
        ))
    }

    func clearCachedArticleContent(for articleId: Int64) throws {
        let target = articles.filter(articleID == articleId)
        try database.run(target.update(articleHasFullText <- false))
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

    func cachedArticleTranslation(for articleId: Int64) throws -> (title: String?, text: String?)? {
        let query = articles.filter(articleID == articleId)
        guard let row = try database.pluck(query) else { return nil }
        let title = row[articleTranslatedTitle]
        let text = row[articleTranslatedText]
        guard title != nil || text != nil else { return nil }
        return (title: title, text: text)
    }

    func cacheArticleTranslation(title: String?, text: String?, for articleId: Int64) throws {
        let target = articles.filter(articleID == articleId)
        try database.run(target.update(
            articleTranslatedTitle <- title,
            articleTranslatedText <- text
        ))
    }

    func clearCachedArticleTranslation(for articleId: Int64) throws {
        let target = articles.filter(articleID == articleId)
        try database.run(target.update(
            articleTranslatedTitle <- nil,
            articleTranslatedText <- nil
        ))
    }
}
