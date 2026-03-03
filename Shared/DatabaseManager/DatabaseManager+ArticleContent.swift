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
}
