import Foundation

public extension FeedManager {

    // MARK: - OPML Export

    func exportOPML() -> String {
        OPMLManager.shared.generateOPML(from: feeds.filter { $0.isOPMLPortable })
    }

    // MARK: - OPML Import

    func importOPML(data: Data, overwrite: Bool) throws -> Int {
        let opmlFeeds = OPMLManager.shared.parseOPML(data: data)
            .filter { Feed.isOPMLPortableURL($0.xmlURL) }
        guard !opmlFeeds.isEmpty else { return 0 }

        if overwrite {
            let existing = try database.allFeeds()
            for feed in existing {
                try database.deleteFeed(id: feed.id)
            }
        }

        var inserted: [InsertedOPMLFeed] = []
        for opmlFeed in opmlFeeds {
            if database.feedExists(url: opmlFeed.xmlURL) {
                continue
            }
            let siteURL = opmlFeed.htmlURL.isEmpty
                ? (FeedProviderRegistry.inferredSiteURL(forFeedURL: opmlFeed.xmlURL) ?? "")
                : opmlFeed.htmlURL
            let feedID = try database.insertFeed(
                title: opmlFeed.title,
                url: opmlFeed.xmlURL,
                siteURL: siteURL,
                description: opmlFeed.description,
                category: opmlFeed.category
            )
            generateAcronymIcon(feedID: feedID, title: opmlFeed.title)
            inserted.append(InsertedOPMLFeed(
                feedID: feedID,
                url: opmlFeed.xmlURL,
                siteURL: siteURL,
                category: opmlFeed.category,
                title: opmlFeed.title
            ))
        }

        loadFromDatabase()

        if !inserted.isEmpty {
            Task { [inserted] in
                for row in inserted {
                    guard !row.siteURL.isEmpty else { continue }
                    await self.enrichInsertedFeed(
                        feedID: row.feedID,
                        url: row.url,
                        siteURL: row.siteURL,
                        category: row.category,
                        fallbackTitle: row.title
                    )
                }
                await self.loadFromDatabaseInBackground()
            }
        }

        return inserted.count
    }
}

private struct InsertedOPMLFeed: Sendable {
    let feedID: Int64
    let url: String
    let siteURL: String
    let category: String?
    let title: String
}
