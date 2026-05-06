import Foundation
import os
import WebKit

// MARK: - API Fetching

extension InstagramProvider {

    struct InstagramCookies {
        let csrfToken: String
        let sessionID: String
        let allCookies: [HTTPCookie]
    }

    func performFetch(profileURL: URL) async -> InstagramProfileFetchResult {
        guard let handle = Self.extractIdentifier(from: profileURL) else {
            log("InstagramProvider", "Failed to extract handle from URL: \(profileURL)")
            return InstagramProfileFetchResult(posts: [], profileImageURL: nil, displayName: nil)
        }

        log("InstagramProvider", "Fetching profile for handle: \(handle)")

        await Self.awaitHumanPacing()

        guard let cookies = Self.getInstagramCookies() else {
            log("InstagramProvider", "No Instagram session cookies found")
            return InstagramProfileFetchResult(posts: [], profileImageURL: nil, displayName: nil)
        }

        // swiftlint:disable:next line_length
        log("InstagramProvider", "Got cookies - csrf: \(cookies.csrfToken.prefix(20))..., total cookies: \(cookies.allCookies.count)")

        let session = makeSession(cookies: cookies)

        let profileData = await fetchProfileInfo(
            username: handle, cookies: cookies, session: session
        )

        Self.persistRotatedCookies(from: session)
        Self.markRequestCompleted()

        guard let profileData else {
            log("InstagramProvider", "Failed to fetch profile info for \(handle)")
            return InstagramProfileFetchResult(posts: [], profileImageURL: nil, displayName: nil)
        }

        log("InstagramProvider", "Fetched \(profileData.posts.count) posts, name: \(profileData.displayName ?? "nil")")

        return profileData
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

        log("InstagramProvider", "Human-pacing delay: \(String(format: "%.2f", delay))s")
        try? await Task.sleep(for: .seconds(delay))
    }

    /// Short randomised pause between back-to-back API calls inside a single fetch.
    static func awaitIntraFetchPause() async {
        let delay = TimeInterval.random(in: 0.9...2.6)
        log("InstagramProvider", "Intra-fetch pause: \(String(format: "%.2f", delay))s")
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

    // MARK: - Cookies

    /// Reads the current Instagram session from the Keychain-backed cookie jar.
    static func getInstagramCookies() -> InstagramCookies? {
        guard let cookies = InstagramProvider.cookieStore.load() else {
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
    ) async -> InstagramProfileFetchResult? {
        guard let url = URL(
            string: "https://www.instagram.com/api/v1/users/web_profile_info/?username=\(username)"
        ) else {
            return nil
        }

        let request = buildRequest(url: url, cookies: cookies)

        log("InstagramProvider", "Profile info request: \(url)")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            log("InstagramProvider", "Profile info network error: \(error)")
            return nil
        }

        guard let httpResponse = response as? HTTPURLResponse else { return nil }

        log("InstagramProvider", "Profile info status: \(httpResponse.statusCode)")
        if let body = String(data: data, encoding: .utf8) {
            log("InstagramProvider", "Profile info response: \(body.prefix(1000))")
        }

        guard httpResponse.statusCode == 200 else { return nil }

        guard var result = Self.parseProfileResponse(
            data: data, username: username
        ) else {
            return nil
        }

        // web_profile_info often returns empty edges even when posts exist; fall back to feed endpoint.
        if result.posts.isEmpty, let userId = Self.extractUserID(from: data) {
            log("InstagramProvider", "Profile had 0 posts, fetching feed for user ID: \(userId)")
            await Self.awaitIntraFetchPause()
            let feedPosts = await fetchUserFeed(
                userId: userId, username: username,
                displayName: result.displayName,
                cookies: cookies, session: session
            )
            if !feedPosts.isEmpty {
                result = InstagramProfileFetchResult(
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

        log("InstagramProvider", "Feed request: \(url)")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            log("InstagramProvider", "Feed network error: \(error)")
            return []
        }

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            log("InstagramProvider", "Feed request failed: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            return []
        }

        if let body = String(data: data, encoding: .utf8) {
            log("InstagramProvider", "Feed response: \(body.prefix(500))")
        }

        return Self.parseFeedResponse(
            data: data, username: username, displayName: displayName
        )
    }
}
