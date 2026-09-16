import Foundation
@preconcurrency import SQLite

public nonisolated extension DatabaseManager {

    /// Renames a bookmark without touching the original page title, so the
    /// original can always be restored. Passing `nil` clears the rename.
    func setCustomTitle(_ title: String?, forArticleID aid: Int64) throws {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let stored: String? = (trimmed?.isEmpty == false) ? trimmed : nil
        try database.run(
            articles.filter(articleID == aid).update(articleCustomTitle <- stored)
        )
    }

    func customTitle(forArticleID aid: Int64) throws -> String? {
        try database.pluck(
            articles.filter(articleID == aid).select(articleCustomTitle)
        )?[articleCustomTitle]
    }
}
