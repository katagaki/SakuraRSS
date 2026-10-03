import Foundation

public extension InstagramProvider {

    nonisolated static func extractPostShortcode(from url: URL) -> String? {
        guard isInstagramPostURL(url) else { return nil }
        let components = url.pathComponents
        guard components.count >= 3 else { return nil }
        let shortcode = components[2]
        return shortcode.isEmpty ? nil : shortcode
    }

    /// Builds the comments-page URL by inserting `comments/` after the
    /// post shortcode.
    nonisolated static func commentsPageURL(forShortcode shortcode: String) -> URL? {
        URL(string: "https://www.instagram.com/p/\(shortcode)/comments/")
    }

    /// Fetches the server-rendered comments HTML for a post, extracts the
    /// embedded JSON payload, and returns the top `limit` ranked comments.
    func fetchPostComments(shortcode: String, limit: Int) async -> [ParsedInstagramComment] {
        guard limit > 0,
              let url = Self.commentsPageURL(forShortcode: shortcode),
              let cookies = Self.getInstagramCookies() else { return [] }

        let session = makeCommentsSession(cookies: cookies)
        defer { session.finishTasksAndInvalidate() }
        let referer = "https://www.instagram.com/p/\(shortcode)/"
        let request = buildHTMLRequest(url: url, referer: referer)

        let data: Data
        do {
            data = try await Self.performRequest(request, session: session)
        } catch {
            log("InstagramProvider", "Comments page network error: \(error)")
            return []
        }

        guard let html = String(data: data, encoding: .utf8) else { return [] }

        let parsed = Self.parseCommentsHTML(html, shortcode: shortcode)
        let ranked = parsed
            .sorted { $0.likeCount > $1.likeCount }
            .prefix(limit)
        return Array(ranked)
    }

    private func makeCommentsSession(cookies: InstagramCookies) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = true
        config.httpCookieAcceptPolicy = .always
        if let storage = config.httpCookieStorage {
            for cookie in cookies.allCookies {
                storage.setCookie(cookie)
            }
        }
        return URLSession(configuration: config)
    }

}
