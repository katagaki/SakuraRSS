import Foundation
import os
import WebKit

// MARK: - API Fetching

extension InstagramProfileScraper {

    struct InstagramCookies {
        let csrfToken: String
        let sessionID: String
        let allCookies: [HTTPCookie]
    }

    func performFetch(profileURL: URL) async -> InstagramProfileScrapeResult {
        guard let handle = Self.extractHandle(from: profileURL) else {
            #if DEBUG
            print("[InstagramProfileScraper] Failed to extract handle from URL: \(profileURL)")
            #endif
            return InstagramProfileScrapeResult(posts: [], profileImageURL: nil, displayName: nil)
        }

        #if DEBUG
        print("[InstagramProfileScraper] Fetching profile for handle: \(handle)")
        #endif

        await Self.awaitHumanPacing()

        guard let cookies = Self.getInstagramCookies() else {
            #if DEBUG
            print("[InstagramProfileScraper] No Instagram session cookies found")
            #endif
            return InstagramProfileScrapeResult(posts: [], profileImageURL: nil, displayName: nil)
        }

        #if DEBUG
        print("[InstagramProfileScraper] Got cookies - csrf: \(cookies.csrfToken.prefix(20))..., "
              + "total cookies: \(cookies.allCookies.count)")
        #endif

        let session = makeSession(cookies: cookies)

        let profileData = await fetchProfileInfo(
            username: handle, cookies: cookies, session: session
        )

        Self.persistRotatedCookies(from: session)
        Self.markRequestCompleted()

        guard let profileData else {
            #if DEBUG
            print("[InstagramProfileScraper] Failed to fetch profile info for \(handle)")
            #endif
            return InstagramProfileScrapeResult(posts: [], profileImageURL: nil, displayName: nil)
        }

        #if DEBUG
        print("[InstagramProfileScraper] Fetched \(profileData.posts.count) posts, "
              + "name: \(profileData.displayName ?? "nil")")
        #endif

        return profileData
    }

    /// Writes rotated Instagram cookies from the URLSession jar back to Keychain.
    private static func persistRotatedCookies(from session: URLSession) {
        guard let storage = session.configuration.httpCookieStorage else { return }
        let updated = (storage.cookies ?? []).filter {
            $0.domain.lowercased().contains("instagram.com")
        }
        guard !updated.isEmpty else { return }
        InstagramProfileScraper.cookieStore.save(updated)
    }

    // MARK: - Human-Like Pacing

    private static let lastRequestCompletedAt = OSAllocatedUnfairLock<Date?>(
        initialState: nil
    )

    static func markRequestCompleted() {
        lastRequestCompletedAt.withLock { $0 = Date() }
    }

    /// Sleeps for a randomised interval so consecutive Instagram requests look human-paced.
    static func awaitHumanPacing() async {
        let lastCompleted = lastRequestCompletedAt.withLock { $0 }

        let minCooldown: TimeInterval = 3.5
        let maxCooldown: TimeInterval = 9.0

        var delay = TimeInterval.random(in: 0.4...1.8)
        if let lastCompleted {
            let elapsed = Date().timeIntervalSince(lastCompleted)
            let targetCooldown = TimeInterval.random(in: minCooldown...maxCooldown)
            if elapsed < targetCooldown {
                delay = max(delay, targetCooldown - elapsed)
            }
        }

        #if DEBUG
        print("[InstagramProfileScraper] Human-pacing delay: \(String(format: "%.2f", delay))s")
        #endif
        try? await Task.sleep(for: .seconds(delay))
    }

    /// Short randomised pause between back-to-back API calls inside a single scrape.
    static func awaitIntraScrapePause() async {
        let delay = TimeInterval.random(in: 0.9...2.6)
        #if DEBUG
        print("[InstagramProfileScraper] Intra-scrape pause: \(String(format: "%.2f", delay))s")
        #endif
        try? await Task.sleep(for: .seconds(delay))
    }

    // MARK: - Accept-Language

    /// Accept-Language header value derived from the user's preferred locales, Safari-style.
    static var acceptLanguageHeader: String {
        let preferred = Locale.preferredLanguages.prefix(5)
        guard !preferred.isEmpty else { return "en-US,en;q=0.9" }
        return preferred.enumerated().map { index, lang in
            if index == 0 { return lang }
            let quality = max(0.1, 1.0 - Double(index) * 0.1)
            return "\(lang);q=\(String(format: "%.1f", quality))"
        }.joined(separator: ",")
    }

    // MARK: - Cookie Warming

    @MainActor
    private static var cookieStoreWarmed = false

    /// Loads Instagram in a WKWebView to restore its persisted cookie jar from disk.
    /// Used only during the one-time Keychain migration.
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

    /// Reads the current Instagram session from the Keychain-backed cookie jar.
    static func getInstagramCookies() -> InstagramCookies? {
        guard let cookies = InstagramProfileScraper.cookieStore.load() else {
            return nil
        }

        var csrfToken: String?
        var sessionID: String?
        for cookie in cookies {
            if cookie.name == "csrftoken" { csrfToken = cookie.value }
            if cookie.name == "sessionid" { sessionID = cookie.value }
        }

        guard let csrf = csrfToken, let session = sessionID else { return nil }
        return InstagramCookies(csrfToken: csrf, sessionID: session,
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

        let cookieHeader = HTTPCookie.requestHeaderFields(with: cookies.allCookies)
        for (key, value) in cookieHeader {
            request.setValue(value, forHTTPHeaderField: key)
        }

        return request
    }

    // MARK: - Profile Info + Posts

    func fetchProfileInfo(
        username: String, cookies: InstagramCookies, session: URLSession
    ) async -> InstagramProfileScrapeResult? {
        guard let url = URL(
            string: "https://www.instagram.com/api/v1/users/web_profile_info/?username=\(username)"
        ) else {
            return nil
        }

        let request = buildRequest(url: url, cookies: cookies)

        #if DEBUG
        print("[InstagramProfileScraper] Profile info request: \(url)")
        #endif

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            #if DEBUG
            print("[InstagramProfileScraper] Profile info network error: \(error)")
            #endif
            return nil
        }

        guard let httpResponse = response as? HTTPURLResponse else { return nil }

        #if DEBUG
        print("[InstagramProfileScraper] Profile info status: \(httpResponse.statusCode)")
        if let body = String(data: data, encoding: .utf8) {
            print("[InstagramProfileScraper] Profile info response: \(body.prefix(1000))")
        }
        #endif

        guard httpResponse.statusCode == 200 else { return nil }

        guard var result = Self.parseProfileResponse(
            data: data, username: username
        ) else {
            return nil
        }

        // web_profile_info often returns empty edges even when posts exist; fall back to feed endpoint.
        if result.posts.isEmpty, let userId = Self.extractUserID(from: data) {
            #if DEBUG
            print("[InstagramProfileScraper] Profile had 0 posts, "
                  + "fetching feed for user ID: \(userId)")
            #endif
            await Self.awaitIntraScrapePause()
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

    /// Fetches posts from the user feed endpoint when `web_profile_info` edges are empty.
    private func fetchUserFeed(
        userId: String, username: String, displayName: String?,
        cookies: InstagramCookies, session: URLSession
    ) async -> [ParsedInstagramPost] {
        guard let url = URL(
            string: "https://www.instagram.com/api/v1/feed/user/\(userId)/"
        ) else {
            return []
        }

        let profileReferer = "https://www.instagram.com/\(username)/"
        let request = buildRequest(url: url, cookies: cookies, referer: profileReferer)

        #if DEBUG
        print("[InstagramProfileScraper] Feed request: \(url)")
        #endif

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            #if DEBUG
            print("[InstagramProfileScraper] Feed network error: \(error)")
            #endif
            return []
        }

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            #if DEBUG
            print("[InstagramProfileScraper] Feed request failed: "
                  + "\((response as? HTTPURLResponse)?.statusCode ?? -1)")
            #endif
            return []
        }

        #if DEBUG
        if let body = String(data: data, encoding: .utf8) {
            print("[InstagramProfileScraper] Feed response: \(body.prefix(500))")
        }
        #endif

        return Self.parseFeedResponse(
            data: data, username: username, displayName: displayName
        )
    }
}
