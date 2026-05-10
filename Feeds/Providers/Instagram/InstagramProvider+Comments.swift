import Foundation

/// Fetches the top comments under an Instagram post by scraping the
/// server-rendered comments page. Instagram embeds the comment payload
/// inside a `<script type="application/json">` block; the JSON exposes
/// `xdt_api__v1__media__media_id__comments__connection.edges` which mirror
/// the v1 comment objects (user, text, created_at, like count).
extension InstagramProvider: CommentsProvider {

    nonisolated static func canProvideComments(for article: Article, in feed: Feed?) -> Bool {
        guard UserDefaults.standard.bool(forKey: "Labs.InstagramProfileFeeds"),
              hasSession() else { return false }
        return commentsURL(for: article, in: feed) != nil
    }

    nonisolated static func commentsURL(for article: Article, in feed: Feed?) -> URL? {
        if let feed, !feed.isInstagramFeed { return nil }
        guard let url = URL(string: article.url),
              isInstagramPostURL(url),
              extractPostShortcode(from: url) != nil else {
            return nil
        }
        return url
    }

    static func fetchComments(
        for article: Article, in feed: Feed?, limit: Int
    ) async throws -> [FetchedComment] {
        guard limit > 0,
              let postURL = commentsURL(for: article, in: feed),
              let shortcode = extractPostShortcode(from: postURL) else {
            log("Comments", "Instagram fetchComments aborted (no shortcode) article id=\(article.id)")
            return []
        }
        log("Comments", "Instagram comments fetch begin shortcode=\(shortcode)")

        let parsed = await InstagramProvider().fetchPostComments(
            shortcode: shortcode, limit: limit
        )
        log("Comments", "Instagram comments parsed shortcode=\(shortcode) count=\(parsed.count)")

        return parsed.map { reply in
            FetchedComment(
                author: "@\(reply.authorHandle)",
                body: reply.text,
                createdDate: reply.publishedDate,
                sourceURL: reply.sourceURL
            )
        }
    }
}
