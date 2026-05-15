import Foundation
import UIKit

public extension FeedManager {

    // MARK: - Instagram Profile Feeds

    func refreshInstagramFeed(
        _ feed: Feed,
        reloadData: Bool = true,
        skipImagePreload: Bool = false,
        runNLP: Bool = true,
        contentOnly: Bool = false
    ) async throws {
        log("InstagramProfile", "refresh begin id=\(feed.id) title=\(feed.title) contentOnly=\(contentOnly)")
        if let lastFetched = feed.lastFetched,
           let interval = RefreshTimeoutDomains.refreshTimeout(for: feed.domain),
           Date().timeIntervalSince(lastFetched) < interval {
            let remaining = interval - Date().timeIntervalSince(lastFetched)
            log("InstagramProfile", "Skipping refresh for @\(feed.title) - \(Int(remaining))s until next allowed fetch")
            return
        }

        guard let handle = InstagramProvider.identifierFromFeedURL(feed.url),
              let profileURL = InstagramProvider.profileURL(for: handle) else {
            log("InstagramProfile", "Could not derive handle/profileURL id=\(feed.id) url=\(feed.url)")
            return
        }
        log("InstagramProfile", "fetching @\(handle) id=\(feed.id)")

        let fetcher = InstagramProvider()
        let result = await fetcher.fetchProfile(profileURL: profileURL)
        // swiftlint:disable:next line_length
        log("InstagramProfile", "fetched @\(handle) posts=\(result.posts.count) displayName=\(result.displayName ?? "nil")")

        let postTuples = Self.makeInstagramArticleItems(from: result.posts)
        let feedTitle = result.displayName ?? feed.title
        let profileImage = await loadInstagramProfileImage(
            result: result, feed: feed, contentOnly: contentOnly
        )

        try await runInstagramPipelineTask(
            feedID: feed.id,
            feedTitle: feedTitle,
            postTuples: postTuples,
            skipImagePreload: skipImagePreload,
            runNLP: runNLP
        )

        if !contentOnly {
            await applyFetcherMetadataRefresh(
                feed: feed, fetchdTitle: feedTitle, profileImage: profileImage
            )
        }

        if reloadData {
            await loadFromDatabaseInBackground(animated: true)
        }
        log("InstagramProfile", "refresh end id=\(feed.id)")
    }

    private func runInstagramPipelineTask(
        feedID: Int64,
        feedTitle: String,
        postTuples: [ArticleInsertItem],
        skipImagePreload: Bool,
        runNLP: Bool
    ) async throws {
        let database = database
        let pipelineTask = Task.detached {
            let insertedIDs = (try? database.insertArticles(
                feedID: feedID, articles: postTuples
            )) ?? []
            log("InstagramProfile", "inserted id=\(feedID) new=\(insertedIDs.count)/\(postTuples.count)")
            await FeedManager.runPostInsertPipeline(
                insertedIDs: insertedIDs,
                feedTitle: feedTitle,
                skipImagePreload: skipImagePreload,
                runNLP: runNLP
            )
            try database.updateFeedLastFetched(id: feedID, date: Date())
        }
        try await withTaskCancellationHandler {
            try await pipelineTask.value
        } onCancel: {
            pipelineTask.cancel()
        }
    }

    private static func makeInstagramArticleItems(
        from posts: [ParsedInstagramPost]
    ) -> [ArticleInsertItem] {
        posts.map { post in
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
    }

    private func loadInstagramProfileImage(
        result: InstagramProfileFetchResult, feed: Feed, contentOnly: Bool
    ) async -> UIImage? {
        guard !contentOnly, feed.lastFetched == nil,
              let imageURLString = result.profileImageURL,
              let imageURL = URL(string: imageURLString),
              let (imageData, _) = try? await Iconography.urlSession.data(from: imageURL) else {
            return nil
        }
        return UIImage(data: imageData)
    }

    var hasInstagramFeeds: Bool {
        feeds.contains { InstagramProvider.isFeedURL($0.url) }
    }
}
