import Foundation

extension FeedManager {

    // MARK: - X Profile Feeds

    @MainActor
    func refreshXFeed(_ feed: Feed) async throws {
        guard let handle = XProfileScraper.handleFromFeedURL(feed.url),
              let profileURL = XProfileScraper.profileURL(for: handle) else { return }

        let scraper = XProfileScraper()
        let result = await scraper.scrapeProfile(profileURL: profileURL)

        for tweet in result.tweets {
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

        // Set the profile photo as feed icon if we don't have one yet
        if let imageURL = result.profileImageURL, feed.customIconURL == nil {
            try? database.updateFeedDetails(
                id: feed.id, title: feed.title, url: feed.url,
                customIconURL: imageURL
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
