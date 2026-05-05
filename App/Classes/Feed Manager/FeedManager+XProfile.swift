import Foundation
import UIKit

extension FeedManager {

    // MARK: - X Profile Feeds

    // swiftlint:disable:next function_body_length
    func refreshXFeed(
        _ feed: Feed,
        reloadData: Bool = true,
        skipImagePreload: Bool = false,
        runNLP: Bool = true,
        contentOnly: Bool = false
    ) async throws {
        log("XProfile", "refresh begin id=\(feed.id) title=\(feed.title) contentOnly=\(contentOnly)")
        if let lastFetched = feed.lastFetched,
           let interval = RefreshTimeoutDomains.refreshTimeout(for: feed.domain),
           Date().timeIntervalSince(lastFetched) < interval {
            let remaining = interval - Date().timeIntervalSince(lastFetched)
            log("XProfile", "Skipping refresh for @\(feed.title) - \(Int(remaining))s until next allowed fetch")
            return
        }

        guard let handle = XProfileFetcher.identifierFromFeedURL(feed.url),
              let profileURL = XProfileFetcher.profileURL(for: handle) else {
            log("XProfile", "Could not derive handle/profileURL id=\(feed.id) url=\(feed.url)")
            return
        }
        log("XProfile", "fetching @\(handle) id=\(feed.id)")

        let fetcher = XProfileFetcher()
        let result = await fetcher.fetchProfile(
            profileURL: profileURL,
            autoRepairQueryIDs: !contentOnly
        )
        log("XProfile", "fetched @\(handle) tweets=\(result.tweets.count) displayName=\(result.displayName ?? "nil")")

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

        var profileImage: UIImage?
        if !contentOnly, feed.lastFetched == nil,
           let imageURLString = result.profileImageURL,
           let imageURL = URL(string: imageURLString),
           let (imageData, _) = try? await IconCache.urlSession.data(from: imageURL) {
            profileImage = UIImage(data: imageData)
        }

        let database = database
        let feedID = feed.id
        try await Task.detached {
            let insertedIDs = (try? database.insertArticles(
                feedID: feedID, articles: tweetTuples
            )) ?? []
            log("XProfile", "inserted id=\(feedID) new=\(insertedIDs.count)/\(tweetTuples.count)")
            await FeedManager.runPostInsertPipeline(
                insertedIDs: insertedIDs,
                feedTitle: feedTitle,
                skipImagePreload: skipImagePreload,
                runNLP: runNLP
            )
            try database.updateFeedLastFetched(id: feedID, date: Date())
        }.value

        if !contentOnly {
            await applyFetcherMetadataRefresh(
                feed: feed, fetchdTitle: feedTitle, profileImage: profileImage
            )
        }

        await MainActor.run { self.bumpDataRevision() }
        if reloadData {
            await loadFromDatabaseInBackground(animated: true)
        }
        log("XProfile", "refresh end id=\(feed.id)")
    }

    var hasXFeeds: Bool {
        feeds.contains { XProfileFetcher.isFeedURL($0.url) }
    }
}
