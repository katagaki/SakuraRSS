import Foundation
@preconcurrency import SQLite

nonisolated extension DatabaseManager {

    // MARK: - Sentiment

    func updateSentimentScore(_ score: Double, for articleId: Int64) throws {
        let target = articles.filter(articleID == articleId)
        try database.run(target.update(articleSentimentScore <- score))
    }

    // MARK: - NLP Processing Flags

    func markSentimentProcessed(articleId: Int64) throws {
        let target = articles.filter(articleID == articleId)
        try database.run(target.update(articleSentimentProcessed <- true))
    }

    func markEntitiesProcessed(articleId: Int64) throws {
        let target = articles.filter(articleID == articleId)
        try database.run(target.update(articleEntitiesProcessed <- true))
    }

    func unprocessedSentimentArticleIDs(since date: Date, limit: Int) throws -> [Int64] {
        let query = articles
            .select(articleID)
            .filter(articleSentimentProcessed == false
                    && articlePublishedDate >= date.timeIntervalSince1970)
            .order(articlePublishedDate.desc)
            .limit(limit)
        return try database.prepare(query).map { $0[articleID] }
    }

    func unprocessedEntitiesArticleIDs(since date: Date, limit: Int) throws -> [Int64] {
        let query = articles
            .select(articleID)
            .filter(articleEntitiesProcessed == false
                    && articlePublishedDate >= date.timeIntervalSince1970)
            .order(articlePublishedDate.desc)
            .limit(limit)
        return try database.prepare(query).map { $0[articleID] }
    }

    // MARK: - Entity CRUD

    func insertEntities(_ entities: [(name: String, type: String)], for articleId: Int64) throws {
        guard !entities.isEmpty else { return }
        try database.transaction {
            for entity in entities {
                try database.run(nlpEntities.insert(
                    nlpEntityArticleID <- articleId,
                    nlpEntityName <- entity.name,
                    nlpEntityType <- entity.type
                ))
            }
        }
    }

    // MARK: - Entity Queries (Topics & People)

    func topEntities(type: String, since date: Date, limit: Int) throws -> [(name: String, count: Int)] {
        let sql = """
            SELECT ne.name, COUNT(*) as cnt
            FROM nlp_entities ne
            JOIN articles a ON ne.article_id = a.id
            WHERE ne.type = ?
              AND a.published_date >= ?
            GROUP BY LOWER(ne.name)
            ORDER BY cnt DESC
            LIMIT ?
            """
        var results: [(name: String, count: Int)] = []
        for row in try database.prepare(sql, type, date.timeIntervalSince1970, limit) {
            if let name = row[0] as? String, let count = row[1] as? Int64 {
                results.append((name: name, count: Int(count)))
            }
        }
        return results
    }

    func topEntities(types: [String], since date: Date, limit: Int) throws -> [(name: String, count: Int)] {
        guard !types.isEmpty else { return [] }
        let placeholders = types.map { _ in "?" }.joined(separator: ", ")
        let sql = """
            SELECT ne.name, COUNT(*) as cnt
            FROM nlp_entities ne
            JOIN articles a ON ne.article_id = a.id
            WHERE ne.type IN (\(placeholders))
              AND a.published_date >= ?
            GROUP BY LOWER(ne.name)
            ORDER BY cnt DESC
            LIMIT ?
            """
        var bindings: [Binding?] = types.map { $0 as Binding? }
        bindings.append(date.timeIntervalSince1970)
        bindings.append(limit)
        var results: [(name: String, count: Int)] = []
        for row in try database.prepare(sql, bindings) {
            if let name = row[0] as? String, let count = row[1] as? Int64 {
                results.append((name: name, count: Int(count)))
            }
        }
        return results
    }

    func articleIDs(forEntity name: String, type: String) throws -> [Int64] {
        let sql = """
            SELECT DISTINCT ne.article_id
            FROM nlp_entities ne
            JOIN articles a ON ne.article_id = a.id
            WHERE LOWER(ne.name) = LOWER(?)
              AND ne.type = ?
            ORDER BY a.published_date DESC
            LIMIT 200
            """
        var ids: [Int64] = []
        for row in try database.prepare(sql, name, type) {
            if let id = row[0] as? Int64 {
                ids.append(id)
            }
        }
        return ids
    }

    func articleIDs(forEntity name: String, types: [String]) throws -> [Int64] {
        guard !types.isEmpty else { return [] }
        let placeholders = types.map { _ in "?" }.joined(separator: ", ")
        let sql = """
            SELECT DISTINCT ne.article_id
            FROM nlp_entities ne
            JOIN articles a ON ne.article_id = a.id
            WHERE LOWER(ne.name) = LOWER(?)
              AND ne.type IN (\(placeholders))
            ORDER BY a.published_date DESC
            LIMIT 200
            """
        var bindings: [Binding?] = [name as Binding?]
        bindings.append(contentsOf: types.map { $0 as Binding? })
        var ids: [Int64] = []
        for row in try database.prepare(sql, bindings) {
            if let id = row[0] as? Int64 {
                ids.append(id)
            }
        }
        return ids
    }

    // MARK: - Similar Content Query

    func articlesInWindow(around article: Article, hours: Int, limit: Int) throws -> [Article] {
        guard let pubDate = article.publishedDate else {
            return try allArticles(limit: limit)
        }
        let windowStart = pubDate.addingTimeInterval(-Double(hours) * 3600)
        let windowEnd = pubDate.addingTimeInterval(Double(hours) * 3600)
        let query = articles
            .filter(articlePublishedDate >= windowStart.timeIntervalSince1970
                    && articlePublishedDate <= windowEnd.timeIntervalSince1970
                    && articleID != article.id)
            .order(articlePublishedDate.desc)
            .limit(limit)
        return try database.prepare(query).map(rowToArticle)
    }

    func sentimentScore(for articleId: Int64) throws -> Double? {
        let query = articles
            .select(articleSentimentScore)
            .filter(articleID == articleId)
            .limit(1)
        return try database.pluck(query)?[articleSentimentScore]
    }

    // MARK: - Reading Analytics

    func totalArticlesRead() throws -> Int {
        try database.scalar(articles.filter(articleIsRead == true).count)
    }

    func readingStreak() throws -> Int {
        let sql = """
            SELECT DISTINCT date(published_date, 'unixepoch', 'localtime') as read_day
            FROM articles
            WHERE is_read = 1 AND published_date IS NOT NULL
            ORDER BY read_day DESC
            """
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current

        var streak = 0
        let calendar = Calendar.current
        var expectedDate = calendar.startOfDay(for: Date())

        for row in try database.prepare(sql) {
            guard let dayString = row[0] as? String,
                  let readDate = formatter.date(from: dayString) else { continue }
            let readDay = calendar.startOfDay(for: readDate)
            if readDay == expectedDate {
                streak += 1
                guard let nextDate = calendar.date(byAdding: .day, value: -1, to: expectedDate) else { break }
                expectedDate = nextDate
            } else if readDay < expectedDate {
                break
            }
        }
        return streak
    }

    func mostReadFeedID() throws -> Int64? {
        let sql = "SELECT feed_id, COUNT(*) as cnt FROM articles WHERE is_read = 1 GROUP BY feed_id ORDER BY cnt DESC LIMIT 1"
        for row in try database.prepare(sql) {
            if let feedID = row[0] as? Int64 {
                return feedID
            }
        }
        return nil
    }

    func totalFeedCount() throws -> Int {
        try database.scalar(feeds.count)
    }

    func deadFeedCount(threshold: Date) throws -> Int {
        let query = feeds.filter(
            feedLastFetched < threshold.timeIntervalSince1970
                || feedLastFetched == nil
        )
        return try database.scalar(query.count)
    }

    // MARK: - NLP Cleanup

    func deleteEntitiesForArticles(olderThan date: Date) throws {
        let sql = """
            DELETE FROM nlp_entities
            WHERE article_id IN (
                SELECT id FROM articles
                WHERE published_date < ? OR published_date IS NULL
            )
            """
        try database.run(sql, date.timeIntervalSince1970)
    }
}
