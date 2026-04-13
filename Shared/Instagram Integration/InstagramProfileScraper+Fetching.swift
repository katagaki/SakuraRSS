import Foundation
import os
import WebKit

// MARK: - API Fetching

extension InstagramProfileScraper {

    struct InstagramCookies {
        let csrfToken: String
        let sessionID: String
        /// All Instagram HTTP cookies for injection into URLSession.
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

        // Enforce a human-like gap since the previous scrape.  When several
        // feeds refresh at once they serialise through `activeScrape`, so
        // without this wait they would fire back-to-back in a tight burst
        // — a strong automation signal.  Spacing them out imitates a user
        // navigating between profiles.
        await Self.awaitHumanPacing()

        guard let cookies = Self.getInstagramCookies() else {
            #if DEBUG
            print("[InstagramProfileScraper] No Instagram session cookies found")
            #endif
            return InstagramProfileScrapeResult(posts: [], profileImageURL: nil, displayName: nil)
        }

        #if DEBUG
        print("[InstagramProfileScraper] Got cookies — csrf: \(cookies.csrfToken.prefix(20))..., "
              + "total cookies: \(cookies.allCookies.count)")
        #endif

        // Session is created once and shared between the profile-info
        // and feed/user requests so cookie rotations from Set-Cookie
        // headers accumulate in a single jar that we can persist at
        // the end of the scrape.
        let session = makeSession(cookies: cookies)

        // Fetch profile info and recent posts
        let profileData = await fetchProfileInfo(
            username: handle, cookies: cookies, session: session
        )

        // Persist any cookies Instagram rotated during the scrape,
        // even if parsing failed — otherwise Keychain drifts stale
        // and the user eventually gets silently signed out.
        Self.persistRotatedCookies(from: session)

        // Record completion time so the next serialised scrape can space
        // itself out relative to when this one finished.
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

    /// Writes rotated cookies from the URLSession jar back to Keychain
    /// so subsequent scrapes pick up refreshed `sessionid` / `csrftoken`
    /// / `mid` values that Instagram issued via `Set-Cookie`.
    private static func persistRotatedCookies(from session: URLSession) {
        guard let storage = session.configuration.httpCookieStorage else { return }
        let updated = (storage.cookies ?? []).filter {
            $0.domain.lowercased().contains("instagram.com")
        }
        guard !updated.isEmpty else { return }
        InstagramProfileScraper.cookieStore.save(updated)
    }

    // MARK: - Human-Like Pacing

    /// Timestamp of the most recently completed Instagram network request.
    /// Used to enforce a minimum inter-scrape gap so a burst of feed
    /// refreshes does not fire back-to-back.  Wrapped in an
    /// `OSAllocatedUnfairLock` because `NSLock.lock()`/`unlock()` are
    /// unavailable from async contexts under Swift 6 strict concurrency.
    private static let lastRequestCompletedAt = OSAllocatedUnfairLock<Date?>(
        initialState: nil
    )

    static func markRequestCompleted() {
        lastRequestCompletedAt.withLock { $0 = Date() }
    }

    /// Sleeps for a randomised interval so consecutive Instagram requests
    /// look like a human navigating, not a script.  The delay combines a
    /// baseline jitter (always applied) with an additional cool-down that
    /// only kicks in when we have just finished a previous request.
    static func awaitHumanPacing() async {
        let lastCompleted = lastRequestCompletedAt.withLock { $0 }

        // Minimum gap between any two serialised scrapes — picked from a
        // fairly wide range so the cadence is not predictable.
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

    /// Short randomised pause used between back-to-back API calls inside
    /// a single scrape (e.g. `web_profile_info` → `feed/user`).  Mimics a
    /// user briefly looking at the profile before scrolling the feed.
    static func awaitIntraScrapePause() async {
        let delay = TimeInterval.random(in: 0.9...2.6)
        #if DEBUG
        print("[InstagramProfileScraper] Intra-scrape pause: \(String(format: "%.2f", delay))s")
        #endif
        try? await Task.sleep(for: .seconds(delay))
    }

    // MARK: - Accept-Language

    /// Accept-Language header value derived from the user's preferred
    /// locales, in the format Safari sends (primary locale at q=1.0,
    /// additional locales at decreasing q values).
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

    /// Loads a WKWebView with instagram.com to force `WKWebsiteDataStore`
    /// to restore its persisted cookie jar from disk.
    ///
    /// This is now only used during the one-time Keychain migration in
    /// `migrateWebKitCookiesIfNeeded()` — normal scrapes read directly
    /// from the Keychain store and do not touch WebKit.
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

    /// Reads the current Instagram session from the Keychain-backed
    /// cookie jar.  Synchronous and thread-safe — no WebKit hop.
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

    func buildRequest(url: URL, cookies: InstagramCookies,
                      referer: String = "https://www.instagram.com/") -> URLRequest {
        // Jitter the timeout slightly so the fingerprint isn't a flat 15s.
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

        // Browser-parity headers.  Mobile Safari sends all of these on
        // every XHR; omitting them makes the request fingerprint stick
        // out against genuine web traffic.
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue(Self.acceptLanguageHeader, forHTTPHeaderField: "Accept-Language")
        // NOTE: Do not set Accept-Encoding manually — URLSession sets its
        // own supported value and transparently decodes the body.  Setting
        // it here would disable that auto-decoding and break JSON parsing.
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")

        // Build the full cookie header from all Instagram cookies
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

        // The web_profile_info endpoint often returns edges: [] even when
        // posts exist. Fall back to the feed endpoint using the user ID.
        if result.posts.isEmpty, let userId = Self.extractUserID(from: data) {
            #if DEBUG
            print("[InstagramProfileScraper] Profile had 0 posts, "
                  + "fetching feed for user ID: \(userId)")
            #endif
            // Mimic a user briefly looking at the profile before the web
            // client fires the follow-up feed XHR.
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

        // Use the profile page as the referer — that is what a real
        // browser sends when the follow-up feed XHR fires from the
        // profile page context.
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
