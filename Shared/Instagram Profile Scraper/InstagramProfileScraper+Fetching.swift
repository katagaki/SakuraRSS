import Foundation
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

        guard let cookies = await Self.getInstagramCookies() else {
            #if DEBUG
            print("[InstagramProfileScraper] No Instagram session cookies found")
            #endif
            return InstagramProfileScrapeResult(posts: [], profileImageURL: nil, displayName: nil)
        }

        #if DEBUG
        print("[InstagramProfileScraper] Got cookies — csrf: \(cookies.csrfToken.prefix(20))..., "
              + "total cookies: \(cookies.allCookies.count)")
        #endif

        // Fetch profile info and recent posts
        guard let profileData = await fetchProfileInfo(
            username: handle, cookies: cookies
        ) else {
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

    // MARK: - Cookies

    @MainActor
    static func getInstagramCookies() async -> InstagramCookies? {
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
        let storage = HTTPCookieStorage.sharedCookieStorage(
            forGroupContainerIdentifier: nil
        )
        for cookie in cookies.allCookies {
            storage.setCookie(cookie)
        }
        config.httpCookieStorage = storage
        return URLSession(configuration: config)
    }

    // MARK: - Request Building

    func buildRequest(url: URL, cookies: InstagramCookies) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
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

        let request = buildRequest(url: url, cookies: cookies)
        let session = makeSession(cookies: cookies)

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

        return Self.parseProfileResponse(data: data, username: username)
    }
}
