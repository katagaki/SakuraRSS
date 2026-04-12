import Foundation
import WebKit

// MARK: - API Fetching

extension InstagramIntegration {

    struct InstagramCookies {
        let csrfToken: String
        let sessionID: String
        /// All Instagram HTTP cookies for injection into URLSession.
        let allCookies: [HTTPCookie]
    }

    func performFetch(profileURL: URL) async -> InstagramProfileScrapeResult {
        guard let handle = InstagramURLHelpers.extractHandle(from: profileURL) else {
            #if DEBUG
            print("[InstagramIntegration] Failed to extract handle from URL: \(profileURL)")
            #endif
            return InstagramProfileScrapeResult(posts: [], profileImageURL: nil, displayName: nil)
        }

        #if DEBUG
        print("[InstagramIntegration] Fetching profile for handle: \(handle)")
        #endif

        guard let cookies = await Self.getInstagramCookies() else {
            #if DEBUG
            print("[InstagramIntegration] No Instagram session cookies found")
            #endif
            return InstagramProfileScrapeResult(posts: [], profileImageURL: nil, displayName: nil)
        }

        #if DEBUG
        print("[InstagramIntegration] Got cookies — csrf: \(cookies.csrfToken.prefix(20))..., "
              + "total cookies: \(cookies.allCookies.count)")
        #endif

        // Fetch profile info and recent posts
        guard let profileData = await fetchProfileInfo(
            username: handle, cookies: cookies
        ) else {
            #if DEBUG
            print("[InstagramIntegration] Failed to fetch profile info for \(handle)")
            #endif
            return InstagramProfileScrapeResult(posts: [], profileImageURL: nil, displayName: nil)
        }

        #if DEBUG
        print("[InstagramIntegration] Fetched \(profileData.posts.count) posts, "
              + "name: \(profileData.displayName ?? "nil")")
        #endif

        return profileData
    }

    // MARK: - Cookie Warming

    @MainActor
    private static var cookieStoreWarmed = false

    /// Loads a WKWebView with instagram.com to force WKWebsiteDataStore
    /// to restore persisted cookies from disk. Without this, cookies may
    /// not be available on cold app launch.
    @MainActor
    static func warmCookieStore() async {
        guard !cookieStoreWarmed else { return }
        cookieStoreWarmed = true

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = sakuraUserAgent

        guard let url = URL(string: "https://www.instagram.com/") else { return }
        webView.load(URLRequest(url: url, timeoutInterval: 10))
        try? await Task.sleep(for: .seconds(2))
    }

    // MARK: - Cookies

    @MainActor
    static func getInstagramCookies() async -> InstagramCookies? {
        await warmCookieStore()

        let store = WKWebsiteDataStore.default()
        let allWebKitCookies = await store.httpCookieStore.allCookies()

        var csrfToken: String?
        var sessionID: String?
        var instagramCookies: [HTTPCookie] = []

        for cookie in allWebKitCookies {
            let domain = cookie.domain.lowercased()
            guard domain.contains("instagram.com") else { continue }
            instagramCookies.append(cookie)
            if cookie.name == "csrftoken" { csrfToken = cookie.value }
            if cookie.name == "sessionid" { sessionID = cookie.value }
        }

        guard let csrf = csrfToken, let session = sessionID else { return nil }
        return InstagramCookies(csrfToken: csrf, sessionID: session,
                                allCookies: instagramCookies)
    }

    // MARK: - Session Building

    /// Creates a URLSession with all Instagram cookies injected into its
    /// cookie storage. This is necessary because Instagram's API performs
    /// redirect-based authentication — the cookies must be present in
    /// the URLSession's cookie jar, not just in request headers.
    private func makeSession(cookies: InstagramCookies) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = true
        config.httpCookieAcceptPolicy = .always
        // Ephemeral config creates its own empty cookie storage;
        // inject all WKWebView cookies so redirects carry auth.
        if let storage = config.httpCookieStorage {
            for cookie in cookies.allCookies {
                storage.setCookie(cookie)
            }
        }
        return URLSession(configuration: config)
    }

    // MARK: - Request Building

    func buildRequest(url: URL, cookies: InstagramCookies) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(cookies.csrfToken, forHTTPHeaderField: "x-csrftoken")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "x-requested-with")
        request.setValue("https://www.instagram.com/", forHTTPHeaderField: "referer")
        request.setValue("https://www.instagram.com", forHTTPHeaderField: "origin")
        request.setValue("same-origin", forHTTPHeaderField: "sec-fetch-site")
        request.setValue("cors", forHTTPHeaderField: "sec-fetch-mode")
        request.setValue("empty", forHTTPHeaderField: "sec-fetch-dest")
        request.setValue(Self.webAppID, forHTTPHeaderField: "x-ig-app-id")

        // Build the full cookie header from all Instagram cookies
        let cookieHeader = HTTPCookie.requestHeaderFields(with: cookies.allCookies)
        for (key, value) in cookieHeader {
            request.setValue(value, forHTTPHeaderField: key)
        }

        return request
    }

    // MARK: - Profile Info + Posts

    func fetchProfileInfo(
        username: String, cookies: InstagramCookies
    ) async -> InstagramProfileScrapeResult? {
        guard let url = URL(
            string: "https://www.instagram.com/api/v1/users/web_profile_info/?username=\(username)"
        ) else {
            return nil
        }

        let session = makeSession(cookies: cookies)
        let request = buildRequest(url: url, cookies: cookies)

        #if DEBUG
        print("[InstagramIntegration] Profile info request: \(url)")
        #endif

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            #if DEBUG
            print("[InstagramIntegration] Profile info network error: \(error)")
            #endif
            return nil
        }

        guard let httpResponse = response as? HTTPURLResponse else { return nil }

        #if DEBUG
        print("[InstagramIntegration] Profile info status: \(httpResponse.statusCode)")
        if let body = String(data: data, encoding: .utf8) {
            print("[InstagramIntegration] Profile info response: \(body.prefix(1000))")
        }
        #endif

        guard httpResponse.statusCode == 200 else { return nil }

        guard var result = Self.parseProfileResponse(
            data: data, username: username
        ) else {
            return nil
        }

        // The web_profile_info endpoint often returns edges: [] even when
        // posts exist. Fall back to the feed endpoint using the user ID.
        if result.posts.isEmpty, let userId = Self.extractUserID(from: data) {
            #if DEBUG
            print("[InstagramIntegration] Profile had 0 posts, "
                  + "fetching feed for user ID: \(userId)")
            #endif
            let feedPosts = await fetchUserFeed(
                userId: userId, username: username,
                displayName: result.displayName,
                cookies: cookies, session: session
            )
            if !feedPosts.isEmpty {
                result = InstagramProfileScrapeResult(
                    posts: feedPosts,
                    profileImageURL: result.profileImageURL,
                    displayName: result.displayName
                )
            }
        }

        return result
    }

    // MARK: - User Feed Endpoint

    /// Fetches posts from the `/api/v1/feed/user/{id}/` endpoint, which
    /// reliably returns post data when `web_profile_info` edges are empty.
    private func fetchUserFeed(
        userId: String, username: String, displayName: String?,
        cookies: InstagramCookies, session: URLSession
    ) async -> [ParsedInstagramPost] {
        guard let url = URL(
            string: "https://www.instagram.com/api/v1/feed/user/\(userId)/"
        ) else {
            return []
        }

        let request = buildRequest(url: url, cookies: cookies)

        #if DEBUG
        print("[InstagramIntegration] Feed request: \(url)")
        #endif

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            #if DEBUG
            print("[InstagramIntegration] Feed network error: \(error)")
            #endif
            return []
        }

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            #if DEBUG
            print("[InstagramIntegration] Feed request failed: "
                  + "\((response as? HTTPURLResponse)?.statusCode ?? -1)")
            #endif
            return []
        }

        #if DEBUG
        if let body = String(data: data, encoding: .utf8) {
            print("[InstagramIntegration] Feed response: \(body.prefix(500))")
        }
        #endif

        return Self.parseFeedResponse(
            data: data, username: username, displayName: displayName
        )
    }
}
