import Foundation

extension FeedManager {

    // MARK: - OPML Export

    func exportOPML() -> String {
        OPMLManager.shared.generateOPML(from: feeds)
    }

    // MARK: - OPML Import

    func importOPML(data: Data, overwrite: Bool) throws -> Int {
        let opmlFeeds = OPMLManager.shared.parseOPML(data: data)
        guard !opmlFeeds.isEmpty else { return 0 }

        if overwrite {
            let existing = try database.allFeeds()
            for feed in existing {
                try database.deleteFeed(id: feed.id)
            }
        }

        var added = 0
        for opmlFeed in opmlFeeds {
            if database.feedExists(url: opmlFeed.xmlURL) {
                continue
            }
            let feedID = try database.insertFeed(
                title: opmlFeed.title,
                url: opmlFeed.xmlURL,
                siteURL: opmlFeed.htmlURL,
                description: opmlFeed.description,
                category: opmlFeed.category
            )
            generateAcronymIcon(feedID: feedID, title: opmlFeed.title)
            added += 1
        }

        loadFromDatabase()
        return added
    }
}
