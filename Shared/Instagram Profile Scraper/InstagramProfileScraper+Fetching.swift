import Foundation
import WebKit

// MARK: - API Fetching

extension InstagramProfileScraper {

    struct InstagramCookies {
        let csrfToken: String
        let sessionID: String
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
        print("[InstagramProfileScraper] Got cookies — csrf: \(cookies.csrfToken.prefix(20))...")
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
        let cookies = await store.httpCookieStore.allCookies()

        var csrfToken: String?
        var sessionID: String?

        for cookie in cookies {
            let domain = cookie.domain.lowercased()
            guard domain.contains("instagram.com") else { continue }
            if cookie.name == "csrftoken" { csrfToken = cookie.value }
            if cookie.name == "sessionid" { sessionID = cookie.value }
        }

        guard let csrf = csrfToken, let session = sessionID else { return nil }
        return InstagramCookies(csrfToken: csrf, sessionID: session)
    }

    // MARK: - Request Building

    func buildRequest(url: URL, cookies: InstagramCookies) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(cookies.csrfToken, forHTTPHeaderField: "x-csrftoken")
        request.setValue("1", forHTTPHeaderField: "x-requested-with")
        request.setValue("https://www.instagram.com/", forHTTPHeaderField: "referer")
        request.setValue(
            "sessionid=\(cookies.sessionID); csrftoken=\(cookies.csrfToken)",
            forHTTPHeaderField: "cookie"
        )
        request.setValue("same-origin", forHTTPHeaderField: "sec-fetch-site")
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

        #if DEBUG
        print("[InstagramProfileScraper] Profile info request: \(url)")
        #endif

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            #if DEBUG
            print("[InstagramProfileScraper] Profile info network error: \(error)")
            #endif
            return nil
        }

        guard let httpResponse = response as? HTTPURLResponse else { return nil }

        #if DEBUG
        print("[InstagramProfileScraper] Profile info status: \(httpResponse.statusCode)")
        #endif

        guard httpResponse.statusCode == 200 else { return nil }

        return Self.parseProfileResponse(data: data, username: username)
    }
}
