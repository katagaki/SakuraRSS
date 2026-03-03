import Foundation
@preconcurrency import SQLite

nonisolated extension DatabaseManager {

    // MARK: - Feed CRUD

    @discardableResult
    func insertFeed(title: String, url: String, siteURL: String,
                    description: String = "", faviconURL: String? = nil,
                    category: String? = nil, isPodcast: Bool = false) throws -> Int64 {
        try database.run(feeds.insert(
            feedTitle <- title,
            feedURL <- url,
            feedSiteURL <- siteURL,
            feedDescription <- description,
            feedFaviconURL <- faviconURL,
            feedCategory <- category,
            feedIsPodcast <- isPodcast
        ))
    }

    func updateFeedIsPodcast(id: Int64, isPodcast: Bool) throws {
        let target = feeds.filter(feedID == id)
        try database.run(target.update(feedIsPodcast <- isPodcast))
    }

    func allFeeds() throws -> [Feed] {
        try database.prepare(feeds.order(feedTitle.asc)).map(rowToFeed)
    }

    func feed(byID id: Int64) throws -> Feed? {
        guard let row = try database.pluck(feeds.filter(feedID == id)) else { return nil }
        return rowToFeed(row)
    }

    func feed(byURL url: String) throws -> Feed? {
        guard let row = try database.pluck(feeds.filter(feedURL == url)) else { return nil }
        return rowToFeed(row)
    }

    func updateFeedLastFetched(id: Int64, date: Date) throws {
        let target = feeds.filter(feedID == id)
        try database.run(target.update(feedLastFetched <- date.timeIntervalSince1970))
    }

    func updateFeed(id: Int64, title: String, category: String?) throws {
        let target = feeds.filter(feedID == id)
        try database.run(target.update(
            feedTitle <- title,
            feedCategory <- category
        ))
    }

    func feedExists(url: String) -> Bool {
        (try? database.pluck(feeds.filter(feedURL == url))) != nil
    }

    func deleteFeed(id: Int64) throws {
        try database.run(articles.filter(articleFeedID == id).delete())
        try database.run(feeds.filter(feedID == id).delete())
    }

    // MARK: - Row Mapping

    func rowToFeed(_ row: Row) -> Feed {
        Feed(
            id: row[feedID],
            title: row[feedTitle],
            url: row[feedURL],
            siteURL: row[feedSiteURL],
            feedDescription: row[feedDescription],
            faviconURL: row[feedFaviconURL],
            lastFetched: row[feedLastFetched].map { Date(timeIntervalSince1970: $0) },
            category: row[feedCategory],
            isPodcast: (try? row.get(feedIsPodcast)) ?? false
        )
    }
}
