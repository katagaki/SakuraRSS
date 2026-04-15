import Foundation

extension FeedManager {

    // MARK: - Instagram Profile Feeds

    /// Minimum interval between Instagram API calls per feed (30 minutes).
    /// Also used by `FaviconProgressBadge` to size the cooldown pie.
    static let instagramRefreshInterval: TimeInterval = 30 * 60

    /// Returns a jittered effective refresh interval.  A hard 30-minute
    /// cadence is a strong automation signal on its own — real users do
    /// not open the same profile on the tick.  We keep 30 min as the
    /// floor and add up to ~10 min of upward jitter so consecutive
    /// refreshes never fall on a fixed schedule.
    private static func jitteredRefreshInterval() -> TimeInterval {
        instagramRefreshInterval + TimeInterval.random(in: 0...(10 * 60))
    }

    func refreshInstagramFeed(_ feed: Feed, reloadData: Bool = true) async throws {
        // Skip if this feed was fetched too recently to avoid rate limits.
        // The cutoff is randomised on each check to avoid a perfectly
        // periodic fetch cadence.
        let effectiveInterval = Self.jitteredRefreshInterval()
        if let lastFetched = feed.lastFetched,
           Date().timeIntervalSince(lastFetched) < effectiveInterval {
            #if DEBUG
            let remaining = effectiveInterval - Date().timeIntervalSince(lastFetched)
            print("[InstagramProfile] Skipping refresh for @\(feed.title) — "
                  + "\(Int(remaining))s until next allowed fetch")
            #endif
            return
        }

        guard let handle = InstagramProfileScraper.handleFromFeedURL(feed.url),
              let profileURL = InstagramProfileScraper.profileURL(for: handle) else { return }

        let scraper = InstagramProfileScraper()
        let result = await scraper.scrapeProfile(profileURL: profileURL)

        // Prepare post data for batch insert
        let postTuples = result.posts.map { post in
            let title = post.text.isEmpty
                ? "Post by @\(post.authorHandle)"
                : String(post.text.prefix(200))
            return ArticleInsertItem(
                title: title,
                url: post.url,
                data: ArticleInsertData(
                    author: post.author.isEmpty ? "@\(post.authorHandle)" : post.author,
                    summary: post.text.isEmpty ? nil : post.text,
                    imageURL: post.imageURL,
                    carouselImageURLs: post.carouselImageURLs,
                    publishedDate: post.publishedDate
                )
            )
        }

        let feedTitle = result.displayName ?? feed.title

        // Run all DB writes off the main thread
        let database = database
        try await Task.detached {
            try database.insertArticles(feedID: feed.id, articles: postTuples)
            try database.updateFeedLastFetched(id: feed.id, date: Date())
            let articlesToIndex = try database.articles(forFeedID: feed.id, limit: postTuples.count)
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

    /// Whether the user has any Instagram profile feeds.
    var hasInstagramFeeds: Bool {
        feeds.contains { InstagramProfileScraper.isInstagramFeedURL($0.url) }
    }
}
