import Foundation

extension FeedManager {

    // MARK: - X Profile Feeds

    /// Minimum interval between X API calls per feed (30 minutes).
    /// Also used by `FaviconProgressBadge` to size the cooldown pie.
    static let xRefreshInterval: TimeInterval = 30 * 60

    func refreshXFeed(_ feed: Feed, reloadData: Bool = true) async throws {
        // Skip if this feed was fetched less than 30 minutes ago to avoid rate limits
        if let lastFetched = feed.lastFetched,
           Date().timeIntervalSince(lastFetched) < Self.xRefreshInterval {
            #if DEBUG
            let remaining = Self.xRefreshInterval - Date().timeIntervalSince(lastFetched)
            print("[XProfile] Skipping refresh for @\(feed.title) — "
                  + "\(Int(remaining))s until next allowed fetch")
            #endif
            return
        }

        guard let handle = XProfileScraper.handleFromFeedURL(feed.url),
              let profileURL = XProfileScraper.profileURL(for: handle) else { return }

        let scraper = XProfileScraper()
        let result = await scraper.scrapeProfile(profileURL: profileURL)

        // Prepare tweet data for batch insert
        let tweetTuples = result.tweets.map { tweet in
            let title = tweet.text.isEmpty
                ? "Post by @\(tweet.authorHandle)"
                : String(tweet.text.prefix(200))
            return ArticleInsertItem(
                title: title,
                url: tweet.url,
                data: ArticleInsertData(
                    author: tweet.author.isEmpty ? "@\(tweet.authorHandle)" : tweet.author,
                    summary: tweet.text.isEmpty ? nil : tweet.text,
                    imageURL: tweet.imageURL,
                    carouselImageURLs: tweet.carouselImageURLs,
                    publishedDate: tweet.publishedDate
                )
            )
        }

        let feedTitle = result.displayName ?? feed.title

        // Run all DB writes off the main thread
        let database = database
        try await Task.detached {
            try database.insertArticles(feedID: feed.id, articles: tweetTuples)
            try database.updateFeedLastFetched(id: feed.id, date: Date())
            let articlesToIndex = try database.articles(forFeedID: feed.id, limit: tweetTuples.count)
            SpotlightIndexer.indexArticles(articlesToIndex, feedTitle: feedTitle)
        }.value

        // Sync the scraped display name if the user hasn't customized
        // the title.  Icons are deliberately left alone here — the user
        // can pull the profile photo via `FeedEditSheet`'s "Fetch icon
        // from feed" action if they want it.
        await applyScraperMetadataRefresh(feed: feed, scrapedTitle: feedTitle)

        if reloadData {
            await loadFromDatabaseInBackground()
        }
    }

    /// Whether the user has any X profile feeds.
    var hasXFeeds: Bool {
        feeds.contains { XProfileScraper.isXFeedURL($0.url) }
    }
}
