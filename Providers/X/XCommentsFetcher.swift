import Foundation

/// Fetches the top replies under an X post by calling the same TweetDetail
/// GraphQL endpoint the app uses for tweet content. The response groups
/// replies into `conversationthread-` modules; the first item of each is the
/// top-level reply. Conforms to `CommentSource` so the article viewer can
/// surface replies alongside Reddit/Hacker News comments.
nonisolated enum XCommentsFetcher: CommentSource {

    static var providerID: String { "x" }

    static func canProvideComments(for article: Article, in feed: Feed?) -> Bool {
        guard UserDefaults.standard.bool(forKey: "Labs.XProfileFeeds"),
              XProfileFetcher.hasSession() else { return false }
        return commentsURL(for: article, in: feed) != nil
    }

    static func commentsURL(for article: Article, in feed: Feed?) -> URL? {
        if let feed, !feed.isXFeed { return nil }
        guard let url = URL(string: article.url),
              XProfileFetcher.isXPostURL(url) else { return nil }
        return url
    }

    static func fetchComments(
        for article: Article, in feed: Feed?, limit: Int
    ) async throws -> [FetchedComment] {
        guard limit > 0,
              let postURL = commentsURL(for: article, in: feed),
              let tweetID = XProfileFetcher.extractTweetID(from: postURL) else {
            log("Comments", "X fetchComments aborted (no tweet ID) article id=\(article.id)")
            return []
        }
        log("Comments", "X TweetDetail fetch begin tweet=\(tweetID)")

        let fetcher = XProfileFetcher()
        guard let data = await fetcher.fetchTweetDetailData(tweetID: tweetID) else {
            log("Comments", "X TweetDetail fetch returned no data tweet=\(tweetID)")
            return []
        }

        let replies = XProfileFetcher.parseTweetDetailReplies(
            data: data, focalTweetID: tweetID, limit: limit
        )
        log("Comments", "X replies parsed tweet=\(tweetID) count=\(replies.count)")

        return replies
            .filter { !$0.text.isEmpty }
            .map { reply in
                FetchedComment(
                    author: reply.author.isEmpty
                        ? "@\(reply.authorHandle)"
                        : reply.author,
                    body: reply.text,
                    createdDate: reply.publishedDate,
                    sourceURL: reply.url
                )
            }
    }
}
