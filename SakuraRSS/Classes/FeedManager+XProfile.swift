import Foundation

extension FeedManager {

    // MARK: - X Profile Feeds

    @MainActor
    func refreshXFeed(_ feed: Feed) async throws {
        guard let handle = XProfileScraper.handleFromFeedURL(feed.url),
              let profileURL = XProfileScraper.profileURL(for: handle) else { return }

        let scraper = XProfileScraper()
        let tweets = await scraper.scrapeTweets(profileURL: profileURL)

        let database = DatabaseManager.shared
        for tweet in tweets {
            let title = tweet.text.isEmpty
                ? "Post by @\(tweet.authorHandle)"
                : String(tweet.text.prefix(200))

            try database.insertArticle(
                feedID: feed.id,
                title: title,
                url: tweet.url,
                data: ArticleInsertData(
                    author: tweet.author.isEmpty ? "@\(tweet.authorHandle)" : tweet.author,
                    summary: tweet.text.isEmpty ? nil : tweet.text,
                    imageURL: tweet.imageURL,
                    publishedDate: tweet.publishedDate
                )
            )
        }

        try database.updateFeedLastFetched(id: feed.id, date: Date())
        loadFromDatabase()
    }

    /// Whether the user has any X profile feeds.
    var hasXFeeds: Bool {
        feeds.contains { XProfileScraper.isXFeedURL($0.url) }
    }
}
