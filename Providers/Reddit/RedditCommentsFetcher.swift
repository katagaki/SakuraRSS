import Foundation

/// Fetches top-ranked Reddit comments for an article via the public
/// `svc/shreddit/comments` endpoint. The endpoint returns a partial HTML
/// fragment containing `<shreddit-comment>` elements; only the top-level
/// (`depth="0"`) comments are surfaced, ranked by score.
nonisolated enum RedditCommentsFetcher: CommentSource {

    static var providerID: String { "reddit" }

    static func canProvideComments(for article: Article, in feed: Feed?) -> Bool {
        commentsURL(for: article, in: feed) != nil
    }

    static func commentsURL(for article: Article, in feed: Feed?) -> URL? {
        if let feed, !feed.isRedditFeed { return nil }
        guard let url = URL(string: article.url),
              let host = url.host?.lowercased(),
              host == "reddit.com" || host.hasSuffix(".reddit.com"),
              RedditPostFetcher.postID(from: url) != nil,
              RedditCommunityFetcher.extractSubredditName(from: url) != nil else {
            return nil
        }
        return url
    }

    static func fetchComments(
        for article: Article, in feed: Feed?, limit: Int
    ) async throws -> [FetchedComment] {
        guard limit > 0,
              let postURL = commentsURL(for: article, in: feed),
              let postID = RedditPostFetcher.postID(from: postURL),
              let subreddit = RedditCommunityFetcher.extractSubredditName(from: postURL),
              let svcURL = svcURL(forSubreddit: subreddit, postID: postID) else {
            log("Comments", "Reddit fetchComments aborted (no post URL/ID) article id=\(article.id)")
            return []
        }
        log("Comments", "Reddit svc fetch begin post=\(postID) subreddit=\(subreddit)")

        let html = try await fetchHTML(at: svcURL)
        let parsed = parseTopLevelComments(html: html, subreddit: subreddit, postID: postID)
        let ranked = parsed
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map(\.comment)
        log(
            "Comments",
            "Reddit comments fetched post=\(postID) parsed=\(parsed.count) usable=\(ranked.count)"
        )
        return Array(ranked)
    }

    private static func fetchHTML(at url: URL) async throws -> String {
        let request = URLRequest.sakura(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        log("Comments", "Reddit GET \(url.absoluteString) status=\(status) bytes=\(data.count)")
        guard let html = String(data: data, encoding: .utf8) else {
            return ""
        }
        return html
    }

    static func svcURL(forSubreddit subreddit: String, postID: String) -> URL? {
        var components = URLComponents(string: "https://www.reddit.com/svc/shreddit/comments/r/\(subreddit)/\(postID)")
        components?.queryItems = [
            URLQueryItem(name: "seeker-session", value: "false"),
            URLQueryItem(name: "render-mode", value: "partial"),
            URLQueryItem(name: "referer", value: "")
        ]
        return components?.url
    }
}
