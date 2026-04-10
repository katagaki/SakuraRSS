import Foundation
@preconcurrency import SQLite

nonisolated extension DatabaseManager {

    // MARK: - Download Path

    func setDownloadPath(_ path: String?, for articleId: Int64) throws {
        let target = articles.filter(articleID == articleId)
        try database.run(target.update(articleDownloadPath <- path))
    }

    func downloadPath(for articleId: Int64) throws -> String? {
        let query = articles.filter(articleID == articleId)
        guard let row = try database.pluck(query) else { return nil }
        return row[articleDownloadPath]
    }

    func downloadedArticleIDs() throws -> [Int64] {
        let query = articles.filter(articleDownloadPath != nil).select(articleID)
        return try database.prepare(query).map { $0[articleID] }
    }

    func clearDownloadPath(for articleId: Int64) throws {
        let target = articles.filter(articleID == articleId)
        try database.run(target.update(articleDownloadPath <- nil))
    }

    // MARK: - Transcript Cache

    func cachedTranscript(for articleId: Int64) throws -> [TranscriptSegment]? {
        let query = articles.filter(articleID == articleId)
        guard let row = try database.pluck(query) else { return nil }
        guard let json = row[articleTranscriptJSON], let data = json.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode([TranscriptSegment].self, from: data)
    }

    func cacheTranscript(_ segments: [TranscriptSegment], for articleId: Int64) throws {
        let data = try JSONEncoder().encode(segments)
        guard let json = String(data: data, encoding: .utf8) else { return }
        let target = articles.filter(articleID == articleId)
        try database.run(target.update(articleTranscriptJSON <- json))
    }

    func clearCachedTranscript(for articleId: Int64) throws {
        let target = articles.filter(articleID == articleId)
        try database.run(target.update(articleTranscriptJSON <- nil))
    }
}
