import Foundation
import UIKit

extension FeedManager {

    // MARK: - Instagram Profile Feeds

    static let instagramRefreshInterval: TimeInterval = 30 * 60

    /// Adds up to 10 minutes of jitter to avoid a fixed-schedule automation signature.
    private static func jitteredRefreshInterval() -> TimeInterval {
        instagramRefreshInterval + TimeInterval.random(in: 0...(10 * 60))
    }

    func refreshInstagramFeed(
        _ feed: Feed,
        reloadData: Bool = true,
        articleInsertCollector: ArticleInsertCollector? = nil
    ) async throws {
        let effectiveInterval = Self.jitteredRefreshInterval()
        if let lastFetched = feed.lastFetched,
           Date().timeIntervalSince(lastFetched) < effectiveInterval {
            #if DEBUG
            let remaining = effectiveInterval - Date().timeIntervalSince(lastFetched)
            print("[InstagramProfile] Skipping refresh for @\(feed.title) - "
                  + "\(Int(remaining))s until next allowed fetch")
            #endif
            return
        }

        guard let handle = InstagramProfileScraper.handleFromFeedURL(feed.url),
              let profileURL = InstagramProfileScraper.profileURL(for: handle) else { return }

        let scraper = InstagramProfileScraper()
        let result = await scraper.scrapeProfile(profileURL: profileURL)

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

        var profileImage: UIImage?
        if feed.lastFetched == nil,
           let imageURLString = result.profileImageURL,
           let imageURL = URL(string: imageURLString),
           let (imageData, _) = try? await FaviconCache.urlSession.data(from: imageURL) {
            profileImage = UIImage(data: imageData)
        }

        let database = database
        try await Task.detached {
            if let articleInsertCollector {
                await articleInsertCollector.add(
                    feedID: feed.id,
                    items: postTuples,
                    feedTitleForSpotlight: feedTitle
                )
            } else {
                let insertedIDs = try database.insertArticles(
                    feedID: feed.id, articles: postTuples
                )
                if !insertedIDs.isEmpty {
                    let articlesToIndex = try database.articles(withIDs: insertedIDs)
                    SpotlightIndexer.indexArticles(articlesToIndex, feedTitle: feedTitle)
                }
            }
            try database.updateFeedLastFetched(id: feed.id, date: Date())
        }.value

        await applyScraperMetadataRefresh(
            feed: feed, scrapedTitle: feedTitle, profileImage: profileImage
        )

        if reloadData {
            await loadFromDatabaseInBackground(animated: true)
        }
    }

    var hasInstagramFeeds: Bool {
        feeds.contains { InstagramProfileScraper.isInstagramFeedURL($0.url) }
    }
}
