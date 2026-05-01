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

    func updateFeedURL(id: Int64, url: String) throws {
        let target = feeds.filter(feedID == id)
        try database.run(target.update(feedURL <- url))
    }

    func updateFeed(id: Int64, title: String, category: String?) throws {
        let target = feeds.filter(feedID == id)
        try database.run(target.update(
            feedTitle <- title,
            feedCategory <- category
        ))
    }

    func updateFeedMuted(id: Int64, isMuted: Bool) throws {
        let target = feeds.filter(feedID == id)
        try database.run(target.update(feedIsMuted <- isMuted))
    }

    func updateFeedDescription(id: Int64, description: String) throws {
        let target = feeds.filter(feedID == id)
        try database.run(target.update(feedDescription <- description))
    }

    func updateFeedDetails(id: Int64, title: String, url: String,
                           customIconURL: String?,
                           isTitleCustomized: Bool) throws {
        let target = feeds.filter(feedID == id)
        try database.run(target.update(
            feedTitle <- title,
            feedURL <- url,
            feedCustomIconURL <- customIconURL,
            feedIsTitleCustomized <- isTitleCustomized
        ))
    }

    func updateFeedAcronymIcon(id: Int64, data: Data?) throws {
        let target = feeds.filter(feedID == id)
        try database.run(target.update(feedAcronymIcon <- data))
    }

    func feedExists(url: String) -> Bool {
        (try? database.pluck(feeds.filter(feedURL == url))) != nil
    }

    func deleteFeed(id: Int64) throws {
        try database.run(articles.filter(articleFeedID == id).delete())
        try database.run(feedRules.filter(ruleFeedID == id).delete())
        try removeDeletedFeedFromLists(feedID: id)
        try database.run(feeds.filter(feedID == id).delete())
    }

    func deleteAllArticles() throws {
        try database.run(articles.filter(articleIsBookmarked == false).delete())
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
            isPodcast: (try? row.get(feedIsPodcast)) ?? false,
            isMuted: (try? row.get(feedIsMuted)) ?? false,
            customIconURL: try? row.get(feedCustomIconURL),
            acronymIcon: try? row.get(feedAcronymIcon),
            isTitleCustomized: (try? row.get(feedIsTitleCustomized)) ?? false
        )
    }
}
