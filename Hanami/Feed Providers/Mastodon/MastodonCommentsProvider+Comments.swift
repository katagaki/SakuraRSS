import Foundation

extension MastodonCommentsProvider: CommentsProvider {

    public nonisolated static func canProvideComments(for article: Article, in feed: Feed?) -> Bool {
        commentsURL(for: article, in: feed) != nil
    }

    public nonisolated static func commentsURL(for article: Article, in feed: Feed?) -> URL? {
        if let feed, !feed.isFediverseFeed { return nil }
        guard let url = URL(string: article.url), isMastodonStatusURL(url) else { return nil }
        return url
    }

    public static func fetchComments(
        for article: Article, in feed: Feed?, limit: Int
    ) async throws -> [FetchedComment] {
        guard limit > 0,
              let statusURL = commentsURL(for: article, in: feed),
              let host = statusURL.host,
              let statusID = statusID(from: statusURL),
              let contextURL = contextURL(forStatusID: statusID, host: host) else {
            log("Comments", "Mastodon fetchComments aborted (no status URL/ID) article id=\(article.id)")
            return []
        }
        log("Comments", "Mastodon context fetch begin host=\(host) status=\(statusID)")

        let request = URLRequest.sakura(url: contextURL)
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        log("Comments", "Mastodon GET \(contextURL.absoluteString) status=\(statusCode) bytes=\(data.count)")
        guard statusCode == 200 else {
            log("Comments", "Mastodon context non-200 status=\(statusCode)")
            return []
        }

        let context = try JSONDecoder().decode(MastodonContext.self, from: data)
        let directReplies = context.descendants
            .filter { $0.inReplyToID == statusID }
            .sorted { ($0.createdDate ?? .distantPast) < ($1.createdDate ?? .distantPast) }
            .prefix(limit)
        let comments = directReplies.map { reply in
            FetchedComment(
                author: reply.displayAuthor,
                body: cleanCommentText(reply.content),
                createdDate: reply.createdDate,
                sourceURL: reply.url ?? reply.uri
            )
        }
        // swiftlint:disable:next line_length
        log("Comments", "Mastodon comments fetched status=\(statusID) usable=\(comments.count)/\(context.descendants.count)")
        return Array(comments)
    }
}
