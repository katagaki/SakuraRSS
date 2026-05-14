import Foundation
import UIKit

public extension FeedManager {

    // MARK: - Bluesky Profile Feeds

    func refreshBlueskyFeed(
        _ feed: Feed,
        reloadData: Bool = true,
        skipImagePreload: Bool = false,
        runNLP: Bool = true,
        contentOnly: Bool = false
    ) async throws {
        log("BlueskyProfile", "refresh begin id=\(feed.id) title=\(feed.title) contentOnly=\(contentOnly)")
        if let lastFetched = feed.lastFetched,
           let interval = RefreshTimeoutDomains.refreshTimeout(for: feed.domain),
           Date().timeIntervalSince(lastFetched) < interval {
            let remaining = interval - Date().timeIntervalSince(lastFetched)
            log("BlueskyProfile", "Skipping refresh for @\(feed.title) - \(Int(remaining))s until next allowed fetch")
            return
        }

        guard let handle = BlueskyProvider.identifierFromFeedURL(feed.url) else {
            log("BlueskyProfile", "Could not derive handle id=\(feed.id) url=\(feed.url)")
            return
        }
        log("BlueskyProfile", "fetching @\(handle) id=\(feed.id)")

        let fetcher = BlueskyProvider()
        let result = await fetcher.fetchAuthorFeed(handle: handle)
        // swiftlint:disable:next line_length
        log("BlueskyProfile", "fetched @\(handle) posts=\(result.posts.count) displayName=\(result.displayName ?? "nil")")

        let postTuples = Self.makeBlueskyArticleItems(from: result.posts)
        let feedTitle = result.displayName ?? feed.title
        let profileImage = await loadBlueskyProfileImage(
            result: result, feed: feed, contentOnly: contentOnly
        )

        let database = database
        let feedID = feed.id
        try await Task.detached {
            let insertedIDs = (try? database.insertArticles(
                feedID: feedID, articles: postTuples
            )) ?? []
            log("BlueskyProfile", "inserted id=\(feedID) new=\(insertedIDs.count)/\(postTuples.count)")
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

        if reloadData {
            await loadFromDatabaseInBackground(animated: true)
        }
        log("BlueskyProfile", "refresh end id=\(feed.id)")
    }

    private static func makeBlueskyArticleItems(
        from posts: [ParsedBlueskyPost]
    ) -> [ArticleInsertItem] {
        posts.map { post in
            let title = post.text.isEmpty
                ? "Post by @\(post.authorHandle)"
                : String(post.text.prefix(200))
            let rowThumbnail = post.images.first?.thumbURL ?? post.videoThumbnailURL
            let contentHTML = makeBlueskyContentHTML(text: post.text, images: post.images)
            return ArticleInsertItem(
                title: title,
                url: post.url,
                data: ArticleInsertData(
                    author: post.author.isEmpty ? "@\(post.authorHandle)" : post.author,
                    summary: post.text.isEmpty ? nil : post.text,
                    content: contentHTML,
                    imageURL: rowThumbnail,
                    publishedDate: post.publishedDate
                )
            )
        }
    }

    private static func makeBlueskyContentHTML(
        text: String, images: [ParsedBlueskyImage]
    ) -> String? {
        if text.isEmpty && images.isEmpty { return nil }
        var html = ""
        if !text.isEmpty {
            let escaped = htmlEscape(text).replacingOccurrences(of: "\n", with: "<br>")
            html += "<p>\(escaped)</p>"
        }
        for image in images {
            let src = htmlEscape(image.fullsizeURL)
            let alt = htmlEscape(image.alt)
            html += "<figure><img src=\"\(src)\" alt=\"\(alt)\"></figure>"
        }
        return html
    }

    private static func htmlEscape(_ value: String) -> String {
        var escaped = value
        escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        escaped = escaped.replacingOccurrences(of: "'", with: "&#39;")
        return escaped
    }

    private func loadBlueskyProfileImage(
        result: BlueskyFeedFetchResult, feed: Feed, contentOnly: Bool
    ) async -> UIImage? {
        guard !contentOnly, feed.lastFetched == nil,
              let imageURLString = result.profileImageURL,
              let imageURL = URL(string: imageURLString),
              let (imageData, _) = try? await Iconography.urlSession.data(from: imageURL) else {
            return nil
        }
        return UIImage(data: imageData)
    }

    var hasBlueskyFeeds: Bool {
        feeds.contains { BlueskyProvider.isFeedURL($0.url) }
    }
}
