import Foundation

/// Fetches the top replies under an X post by calling the same TweetDetail
/// GraphQL endpoint the app uses for tweet content. The response groups
/// replies into `conversationthread-` modules; the first item of each is the
/// top-level reply.
extension XProvider: CommentsProvider {

    nonisolated static func canProvideComments(for article: Article, in feed: Feed?) -> Bool {
        guard UserDefaults.standard.bool(forKey: "Labs.XProfileFeeds"),
              hasSession() else { return false }
        return commentsURL(for: article, in: feed) != nil
    }

    nonisolated static func commentsURL(for article: Article, in feed: Feed?) -> URL? {
        if let feed, !feed.isXFeed { return nil }
        guard let url = URL(string: article.url),
              isXPostURL(url) else { return nil }
        return url
    }

    static func fetchComments(
        for article: Article, in feed: Feed?, limit: Int
    ) async throws -> [FetchedComment] {
        guard limit > 0,
              let postURL = commentsURL(for: article, in: feed),
              let tweetID = extractTweetID(from: postURL) else {
            log("Comments", "X fetchComments aborted (no tweet ID) article id=\(article.id)")
            return []
        }
        log("Comments", "X TweetDetail fetch begin tweet=\(tweetID)")

        let fetcher = XProvider()
        guard let data = await fetcher.fetchTweetDetailData(tweetID: tweetID) else {
            log("Comments", "X TweetDetail fetch returned no data tweet=\(tweetID)")
            return []
        }

        let replies = parseTweetDetailReplies(
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
