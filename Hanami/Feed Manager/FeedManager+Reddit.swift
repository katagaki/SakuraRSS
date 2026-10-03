import Foundation

public extension FeedManager {
    func refreshRedditFeed(_ feed: Feed, options: FeedRefreshOptions) async throws {
        guard !isWithinRedditCooldown(feed) else { return }
        guard let url = URL(string: feed.url),
              let redditFeed = RedditWebFeedURL(url: url) else {
            return
        }

        let database = database
        let feedID = feed.id
        let existingURLs = try await Task.detached {
            try database.existingArticleURLs(forFeedID: feedID)
        }.value
        let existingPostIDs = Set(existingURLs.compactMap { articleURL in
            URL(string: articleURL).flatMap(RedditProvider.postID(from:))
        })

        let scraper = RedditWebFeedScraper()
        let posts = try await scraper.fetch(
            from: redditFeed.pageURL,
            existingPostIDs: existingPostIDs
        )
        let articleItems = posts.map { post in
            ArticleInsertItem(
                title: post.title,
                url: post.url,
                data: ArticleInsertData(
                    author: post.author.isEmpty ? nil : post.author,
                    publishedDate: post.publishedDate
                )
            )
        }

        let feedTitle = feed.title
        try await Task.detached {
            let insertedIDs = try database.insertArticles(
                feedID: feedID,
                articles: articleItems,
                undatedFallbackDate: Date()
            )
            log("RedditFeed", "inserted id=\(feedID) new=\(insertedIDs.count)/\(articleItems.count)")
            await FeedManager.runPostInsertPipeline(
                insertedIDs: insertedIDs,
                feedTitle: feedTitle,
                skipImagePreload: options.skipImagePreload,
                runNLP: options.runNLP
            )
            try database.updateFeedLastFetched(id: feedID, date: Date())
        }.value

        if options.reloadData {
            await loadFromDatabaseInBackground(animated: true)
        }
    }

    private func isWithinRedditCooldown(_ feed: Feed) -> Bool {
        guard let lastFetched = feed.lastFetched,
              let interval = RefreshTimeoutDomains.refreshTimeout(for: feed.domain) else { return false }
        return Date().timeIntervalSince(lastFetched) < interval
    }
}
