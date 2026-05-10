import Foundation

extension InstagramProvider {

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

        await Self.awaitHumanPacing()

        let session = makeCommentsSession(cookies: cookies)
        let referer = "https://www.instagram.com/p/\(shortcode)/"
        let request = buildHTMLRequest(url: url, cookies: cookies, referer: referer)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            log("InstagramProvider", "Comments page network error: \(error)")
            Self.markRequestCompleted()
            return []
        }
        Self.markRequestCompleted()

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let html = String(data: data, encoding: .utf8) else {
            log("InstagramProvider", "Comments page bad status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            return []
        }

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

    /// Mirrors a Safari navigation: text/html Accept, document fetch dest,
    /// no XHR/CSRF headers (the XHR variant returns a JSON shell rather
    /// than the server-rendered comments).
    private func buildHTMLRequest(url: URL, cookies: InstagramCookies,
                                  referer: String) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: max(5, requestTimeoutInterval))
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                         forHTTPHeaderField: "Accept")
        request.setValue(Self.acceptLanguageHeader, forHTTPHeaderField: "Accept-Language")
        request.setValue(referer, forHTTPHeaderField: "referer")
        request.setValue("https://www.instagram.com", forHTTPHeaderField: "origin")
        request.setValue("same-origin", forHTTPHeaderField: "sec-fetch-site")
        request.setValue("navigate", forHTTPHeaderField: "sec-fetch-mode")
        request.setValue("document", forHTTPHeaderField: "sec-fetch-dest")
        request.setValue("?1", forHTTPHeaderField: "sec-fetch-user")

        let cookieHeader = HTTPCookie.requestHeaderFields(with: cookies.allCookies)
        for (key, value) in cookieHeader {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }
}
