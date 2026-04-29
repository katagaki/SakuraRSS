import Foundation
import UIKit

extension FeedManager {

    // MARK: - X Profile Feeds

    /// Minimum interval between X API calls per feed (30 minutes).
    static let xRefreshInterval: TimeInterval = 30 * 60

    func refreshXFeed(
        _ feed: Feed,
        reloadData: Bool = true,
        skipImagePreload: Bool = false,
        runNLP: Bool = true
    ) async throws {
        #if DEBUG
        print("[XProfile] refresh begin id=\(feed.id) title=\(feed.title)")
        #endif
        if let lastFetched = feed.lastFetched,
           Date().timeIntervalSince(lastFetched) < Self.xRefreshInterval {
            #if DEBUG
            let remaining = Self.xRefreshInterval - Date().timeIntervalSince(lastFetched)
            print("[XProfile] Skipping refresh for @\(feed.title) - "
                  + "\(Int(remaining))s until next allowed fetch")
            #endif
            return
        }

        guard let handle = XProfileFetcher.identifierFromFeedURL(feed.url),
              let profileURL = XProfileFetcher.profileURL(for: handle) else {
            #if DEBUG
            print("[XProfile] Could not derive handle/profileURL id=\(feed.id) "
                  + "url=\(feed.url)")
            #endif
            return
        }
        #if DEBUG
        print("[XProfile] fetching @\(handle) id=\(feed.id)")
        #endif

        let fetcher = XProfileFetcher()
        let result = await fetcher.fetchProfile(profileURL: profileURL)
        #if DEBUG
        print("[XProfile] fetched @\(handle) tweets=\(result.tweets.count) "
              + "displayName=\(result.displayName ?? "nil")")
        #endif

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
        if feed.lastFetched == nil,
           let imageURLString = result.profileImageURL,
           let imageURL = URL(string: imageURLString),
           let (imageData, _) = try? await FaviconCache.urlSession.data(from: imageURL) {
            profileImage = UIImage(data: imageData)
        }

        let database = database
        let feedID = feed.id
        try await Task.detached {
            let insertedIDs = (try? database.insertArticles(
                feedID: feedID, articles: tweetTuples
            )) ?? []
            #if DEBUG
            print("[XProfile] inserted id=\(feedID) "
                  + "new=\(insertedIDs.count)/\(tweetTuples.count)")
            #endif
            await FeedManager.runPostInsertPipeline(
                insertedIDs: insertedIDs,
                feedTitle: feedTitle,
                skipImagePreload: skipImagePreload,
                runNLP: runNLP
            )
            try database.updateFeedLastFetched(id: feedID, date: Date())
        }.value

        await applyFetcherMetadataRefresh(
            feed: feed, fetchdTitle: feedTitle, profileImage: profileImage
        )

        await MainActor.run { self.bumpDataRevision() }
        if reloadData {
            await loadFromDatabaseInBackground(animated: true)
        }
        #if DEBUG
        print("[XProfile] refresh end id=\(feed.id)")
        #endif
    }

    var hasXFeeds: Bool {
        feeds.contains { XProfileFetcher.isFeedURL($0.url) }
    }
}
