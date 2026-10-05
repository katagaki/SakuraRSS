import Foundation
import WebKit

// MARK: - API Fetching

public extension InstagramProvider {

    struct InstagramCookies {
        public let csrfToken: String
        public let sessionID: String
        public let allCookies: [HTTPCookie]
    }

    func performFetch(profileURL: URL) async throws -> InstagramProfileFetchResult {
        guard let handle = Self.extractIdentifier(from: profileURL) else {
            throw URLError(.badURL)
        }
        guard let cookies = Self.getInstagramCookies() else {
            throw InstagramFetchError.missingSession
        }
        let session = makeSession(cookies: cookies)
        defer {
            Self.persistRotatedCookies(from: session)
            session.finishTasksAndInvalidate()
        }
        let profileRequest = buildHTMLRequest(url: profileURL)
        let profileData = try await Self.performRequest(profileRequest, session: session)
        guard let html = String(data: profileData, encoding: .utf8),
              let bootstrap = Self.parseProfileHTML(html, username: handle) else {
            throw InstagramFetchError.invalidResponse
        }
        let sessionCookies = session.configuration.httpCookieStorage?.cookies ?? []
        let currentCookies = Self.instagramCookies(from: sessionCookies) ?? cookies
        let postsRequest = try buildPostsRequest(username: handle, bootstrap: bootstrap, cookies: currentCookies)
        let postsData = try await Self.performRequest(postsRequest, session: session)
        guard let result = Self.parsePostsResponse(data: postsData, username: handle, bootstrap: bootstrap) else {
            throw InstagramFetchError.invalidResponse
        }
        log("InstagramProvider", "Fetched @\(handle) posts=\(result.posts.count)")
        return result
    }

    internal func fetchProfileMetadata(profileURL: URL) async throws -> InstagramProfileMetadata {
        guard let handle = Self.extractIdentifier(from: profileURL) else {
            throw URLError(.badURL)
        }
        guard let cookies = Self.getInstagramCookies() else {
            throw InstagramFetchError.missingSession
        }
        let session = makeSession(cookies: cookies)
        defer {
            Self.persistRotatedCookies(from: session)
            session.finishTasksAndInvalidate()
        }
        let profileData = try await Self.performRequest(buildHTMLRequest(url: profileURL), session: session)
        guard let html = String(data: profileData, encoding: .utf8),
              let metadata = Self.parseProfileMetadata(html, username: handle) else {
            throw InstagramFetchError.invalidResponse
        }
        return metadata
    }

    /// Writes rotated Instagram cookies from the URLSession jar back to Keychain.
    private static func persistRotatedCookies(from session: URLSession) {
        guard let storage = session.configuration.httpCookieStorage else { return }
        let updated = (storage.cookies ?? []).filter {
            $0.domain.lowercased().contains("instagram.com")
        }
        guard !updated.isEmpty else { return }
        InstagramProvider.cookieStore.save(updated)
    }

    // MARK: - Accept-Language

    static var acceptLanguageHeader: String { sakuraAcceptLanguage }

    // MARK: - Cookies

    /// Reads the current Instagram session from the Keychain-backed cookie jar.
    nonisolated static func getInstagramCookies() -> InstagramCookies? {
        guard let cookies = InstagramProvider.cookieStore.load() else {
            return nil
        }

        return instagramCookies(from: cookies)
    }

    nonisolated static func instagramCookies(from cookies: [HTTPCookie]) -> InstagramCookies? {
        var csrfToken: String?
        var sessionID: String?
        for cookie in cookies where cookieDomainMatches(cookie.domain.lowercased())
            && (cookie.expiresDate ?? .distantFuture) > Date() {
            if cookie.name == "csrftoken" { csrfToken = cookie.value }
            if cookie.name == "sessionid" { sessionID = cookie.value }
        }

        guard let csrfToken, !csrfToken.isEmpty, let sessionID, !sessionID.isEmpty else { return nil }
        return InstagramCookies(csrfToken: csrfToken, sessionID: sessionID,
                                allCookies: cookies)
    }

    // MARK: - Session Building

    /// Creates a URLSession with Instagram cookies injected so redirects carry auth.
    private func makeSession(cookies: InstagramCookies) -> URLSession {
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

    // MARK: - Request Building

    func buildRequest(url: URL, cookies: InstagramCookies,
                      referer: String = "https://www.instagram.com/") -> URLRequest {
        let jitteredTimeout = requestTimeoutInterval + TimeInterval.random(in: -1.5...2.5)
        var request = URLRequest(url: url, timeoutInterval: max(5, jitteredTimeout))
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(cookies.csrfToken, forHTTPHeaderField: "x-csrftoken")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "x-requested-with")
        request.setValue(referer, forHTTPHeaderField: "referer")
        request.setValue("https://www.instagram.com", forHTTPHeaderField: "origin")
        request.setValue("same-origin", forHTTPHeaderField: "sec-fetch-site")
        request.setValue("cors", forHTTPHeaderField: "sec-fetch-mode")
        request.setValue("empty", forHTTPHeaderField: "sec-fetch-dest")
        request.setValue(Self.webAppID, forHTTPHeaderField: "x-ig-app-id")

        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue(Self.acceptLanguageHeader, forHTTPHeaderField: "Accept-Language")
        // Do not set Accept-Encoding manually; URLSession handles decoding.
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")

        return request
    }

}
