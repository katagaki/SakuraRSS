import Foundation
@preconcurrency import SQLite

nonisolated extension DatabaseManager {

    /// Returns the articles with the given IDs, ordered by published date descending.
    func articles(withIDs ids: [Int64]) throws -> [Article] {
        guard !ids.isEmpty else { return [] }
        let query = articles
            .filter(ids.contains(articleID))
            .order(articlePublishedDate.desc)
        return try database.prepare(query).map(rowToArticle)
    }

    /// Returns articles for a set of feed IDs ordered by published date descending.
    func articles(forFeedIDs feedIDs: [Int64], limit: Int) throws -> [Article] {
        guard !feedIDs.isEmpty else { return [] }
        let query = articles
            .filter(feedIDs.contains(articleFeedID))
            .order(articlePublishedDate.desc)
            .limit(limit)
        return try database.prepare(query).map(rowToArticle)
    }

    /// Returns articles for a set of feed IDs published on or after `date`,
    /// ordered by published date descending.
    func articles(forFeedIDs feedIDs: Set<Int64>, since date: Date) throws -> [Article] {
        guard !feedIDs.isEmpty else { return [] }
        let query = articles
            .filter(feedIDs.contains(articleFeedID)
                    && articlePublishedDate >= date.timeIntervalSince1970)
            .order(articlePublishedDate.desc)
        return try database.prepare(query).map(rowToArticle)
    }

    /// Returns articles for a set of feed IDs that have no `publishedDate`,
    /// ordered by insertion order (id descending).
    func undatedArticles(forFeedIDs feedIDs: Set<Int64>) throws -> [Article] {
        guard !feedIDs.isEmpty else { return [] }
        let query = articles
            .filter(feedIDs.contains(articleFeedID) && articlePublishedDate == nil)
            .order(articleID.desc)
        return try database.prepare(query).map(rowToArticle)
    }

    func article(byID id: Int64) throws -> Article? {
        let query = articles.filter(articleID == id).limit(1)
        return try database.prepare(query).map(rowToArticle).first
    }

    func articles(forFeedID fid: Int64, limit: Int? = nil) throws -> [Article] {
        var query = articles
            .filter(articleFeedID == fid)
            .order(articlePublishedDate.desc)
        if let limit {
            query = query.limit(limit)
        }
        return try database.prepare(query).map(rowToArticle)
    }

    func articleCount(forFeedID fid: Int64) throws -> Int {
        try database.scalar(articles.filter(articleFeedID == fid).count)
    }

    /// Returns the URLs already ingested for `fid`.
    func existingArticleURLs(forFeedID fid: Int64) throws -> Set<String> {
        let query = articles
            .filter(articleFeedID == fid)
            .select(articleURL)
        var result = Set<String>()
        for row in try database.prepare(query) {
            result.insert(row[articleURL])
        }
        return result
    }

    func articles(forFeedID fid: Int64, since date: Date) throws -> [Article] {
        let query = articles
            .filter(articleFeedID == fid
                    && articlePublishedDate >= date.timeIntervalSince1970)
            .order(articlePublishedDate.desc)
        return try database.prepare(query).map(rowToArticle)
    }

    func undatedArticles(forFeedID fid: Int64) throws -> [Article] {
        let query = articles
            .filter(articleFeedID == fid && articlePublishedDate == nil)
            .order(articleID.desc)
        return try database.prepare(query).map(rowToArticle)
    }

    func earliestArticleDate(forFeedID fid: Int64, before date: Date) throws -> Date? {
        let query = articles
            .filter(articleFeedID == fid
                    && articlePublishedDate != nil
                    && articlePublishedDate < date.timeIntervalSince1970)
            .order(articlePublishedDate.desc)
            .limit(1)
        guard let row = try database.pluck(query),
              let timestamp = row[articlePublishedDate] else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    /// Most recent published date across the given feed IDs, or `nil` if none
    /// have a non-null `publishedDate`. Used to anchor date-based batch
    /// windows on the freshest content rather than wall-clock time.
    func latestPublishedDate(forFeedIDs feedIDs: Set<Int64>) throws -> Date? {
        guard !feedIDs.isEmpty else { return nil }
        let query = articles
            .filter(feedIDs.contains(articleFeedID) && articlePublishedDate != nil)
            .order(articlePublishedDate.desc)
            .limit(1)
        guard let row = try database.pluck(query),
              let timestamp = row[articlePublishedDate] else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    func latestPublishedDate() throws -> Date? {
        let query = articles
            .filter(articlePublishedDate != nil)
            .order(articlePublishedDate.desc)
            .limit(1)
        guard let row = try database.pluck(query),
              let timestamp = row[articlePublishedDate] else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    func earliestArticleDate(before date: Date) throws -> Date? {
        let query = articles
            .filter(articlePublishedDate != nil
                    && articlePublishedDate < date.timeIntervalSince1970)
            .order(articlePublishedDate.desc)
            .limit(1)
        guard let row = try database.pluck(query),
              let timestamp = row[articlePublishedDate] else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    func allArticles(limit: Int = 100) throws -> [Article] {
        let query = articles
            .order(articlePublishedDate.desc)
            .limit(limit)
        return try database.prepare(query).map(rowToArticle)
    }

    func allArticles(since date: Date, limit: Int? = 200) throws -> [Article] {
        var query = articles
            .filter(articlePublishedDate >= date.timeIntervalSince1970)
            .order(articlePublishedDate.desc)
        if let limit {
            query = query.limit(limit)
        }
        return try database.prepare(query).map(rowToArticle)
    }

    func allArticles(from startDate: Date, to endDate: Date, limit: Int = 200) throws -> [Article] {
        let query = articles
            .filter(articlePublishedDate >= startDate.timeIntervalSince1970
                    && articlePublishedDate < endDate.timeIntervalSince1970)
            .order(articlePublishedDate.desc)
            .limit(limit)
        return try database.prepare(query).map(rowToArticle)
    }

    func allArticles(before date: Date, limit: Int = 200) throws -> [Article] {
        let query = articles
            .filter(articlePublishedDate < date.timeIntervalSince1970 || articlePublishedDate == nil)
            .order(articlePublishedDate.desc)
            .limit(limit)
        return try database.prepare(query).map(rowToArticle)
    }

    func unreadArticles(limit: Int = 50) throws -> [Article] {
        let query = articles
            .filter(articleIsRead == false)
            .order(articlePublishedDate.desc)
            .limit(limit)
        return try database.prepare(query).map(rowToArticle)
    }

    func searchArticles(query: String) throws -> [Article] {
        let pattern = "%\(query)%"
        let query = articles
            .filter(articleTitle.like(pattern) ||
                    articleAuthor.like(pattern) ||
                    articleSummary.like(pattern))
            .order(articlePublishedDate.desc)
            .limit(200)
        return try database.prepare(query).map(rowToArticle)
    }

    func bookmarkedArticles() throws -> [Article] {
        let query = articles
            .filter(articleIsBookmarked == true)
            .order(articlePublishedDate.desc)
        return try database.prepare(query).map(rowToArticle)
    }

    func bookmarkedCount() throws -> Int {
        try database.scalar(articles.filter(articleIsBookmarked == true).count)
    }

    func articlesForEntity(name: String, types: [String], limit: Int = 10) throws -> [Article] {
        guard !types.isEmpty else { return [] }
        let placeholders = types.map { _ in "?" }.joined(separator: ", ")
        let sql = """
            SELECT DISTINCT a.*
            FROM nlp_entities ne
            JOIN articles a ON ne.article_id = a.id
            WHERE LOWER(ne.name) = LOWER(?)
              AND ne.type IN (\(placeholders))
            ORDER BY a.published_date DESC
            LIMIT ?
            """
        #if DEBUG
        debugPrint("[SQLite] articlesForEntity(name:, types:, limit:) - \(sql)")
        #endif
        var bindings: [Binding?] = [name as Binding?]
        bindings.append(contentsOf: types.map { $0 as Binding? })
        bindings.append(limit)
        var results: [Article] = []
        let stmt = try database.prepare(sql, bindings)
        for row in stmt {
            guard let id = row[0] as? Int64,
                  let feedID = row[1] as? Int64,
                  let title = row[2] as? String,
                  let url = row[3] as? String else { continue }
            let carouselRaw = row[8] as? String
            let carouselURLs = carouselRaw?
                .split(separator: "\n")
                .map(String.init) ?? []
            results.append(Article(
                id: id,
                feedID: feedID,
                title: title,
                url: url,
                author: row[4] as? String,
                summary: row[5] as? String,
                content: row[6] as? String,
                imageURL: row[7] as? String,
                carouselImageURLs: carouselURLs,
                publishedDate: (row[9] as? Double).map { Date(timeIntervalSince1970: $0) },
                isRead: (row[10] as? Int64).map { $0 != 0 } ?? false,
                isBookmarked: (row[11] as? Int64).map { $0 != 0 } ?? false,
                audioURL: row[12] as? String,
                duration: (row[13] as? Int64).map { Int($0) }
            ))
        }
        return results
    }
}
