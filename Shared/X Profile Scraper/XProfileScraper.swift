import Foundation
import WebKit

/// Parsed tweet from an X profile page.
struct ParsedTweet: Sendable {
    let id: String
    let text: String
    let author: String
    let authorHandle: String
    let url: String
    let imageURL: String?
    let publishedDate: Date?
}

/// Result of scraping an X profile: tweets and optional profile metadata.
struct XProfileScrapeResult: Sendable {
    let tweets: [ParsedTweet]
    let profileImageURL: String?
    let displayName: String?
}

/// Fetches tweets from an X (Twitter) profile using GraphQL API calls.
/// Retweets are excluded. Requires the user to be logged in via the default
/// WKWebsiteDataStore so that session cookies are available.
final class XProfileScraper {

    // swiftlint:disable line_length
    private static let bearerToken = "AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA"

    private static let userByScreenNameQueryID = "IGgvgiOx4QZndDHuD3x9TQ"
    private static let userTweetsQueryID = "78bXcjBXrR1q_uIdj22zhQ"

    private static let userByScreenNameFeatures: [String: Bool] = [
        "hidden_profile_subscriptions_enabled": true,
        "profile_label_improvements_pcf_label_in_post_enabled": true,
        "responsive_web_profile_redirect_enabled": false,
        "rweb_tipjar_consumption_enabled": false,
        "verified_phone_label_enabled": false,
        "subscriptions_verification_info_is_identity_verified_enabled": true,
        "subscriptions_verification_info_verified_since_enabled": true,
        "highlights_tweets_tab_ui_enabled": true,
        "responsive_web_twitter_article_notes_tab_enabled": true,
        "subscriptions_feature_can_gift_premium": true,
        "creator_subscriptions_tweet_preview_api_enabled": true,
        "responsive_web_graphql_skip_user_profile_image_extensions_enabled": false,
        "responsive_web_graphql_timeline_navigation_enabled": true
    ]

    // swiftlint:enable line_length

    private static let targetTweetCount = 50

    /// Serialises access so only one fetch runs at a time.
    private static var activeScrape: Task<XProfileScrapeResult, Never>?

    // MARK: - Public

    /// Fetches the most recent tweets (excluding retweets) from the given profile URL.
    /// Also extracts the profile photo URL and display name.
    ///
    /// Only one fetch runs at a time; concurrent calls are serialised.
    func scrapeProfile(profileURL: URL) async -> XProfileScrapeResult {
        if let existing = Self.activeScrape {
            _ = await existing.value
        }

        let task = Task {
            await self.performFetch(profileURL: profileURL)
        }
        Self.activeScrape = task
        let result = await task.value
        Self.activeScrape = nil
        return result
    }

    private func performFetch(profileURL: URL) async -> XProfileScrapeResult {
        guard let handle = Self.extractHandle(from: profileURL) else {
            #if DEBUG
            print("[XProfileScraper] Failed to extract handle from URL: \(profileURL)")
            #endif
            return XProfileScrapeResult(tweets: [], profileImageURL: nil, displayName: nil)
        }

        #if DEBUG
        print("[XProfileScraper] Fetching profile for handle: \(handle)")
        #endif

        guard let cookies = await Self.getXCookies() else {
            #if DEBUG
            print("[XProfileScraper] No X session cookies found")
            #endif
            return XProfileScrapeResult(tweets: [], profileImageURL: nil, displayName: nil)
        }

        #if DEBUG
        print("[XProfileScraper] Got cookies — csrf: \(cookies.csrfToken.prefix(20))…")
        #endif

        // Step 1: Look up user ID, display name, and avatar via UserByScreenName
        guard let userInfo = await fetchUserInfo(
            screenName: handle, cookies: cookies
        ) else {
            #if DEBUG
            print("[XProfileScraper] Failed to fetch user info for \(handle)")
            #endif
            return XProfileScrapeResult(tweets: [], profileImageURL: nil, displayName: nil)
        }

        #if DEBUG
        print("[XProfileScraper] User info — id: \(userInfo.id), "
              + "name: \(userInfo.displayName ?? "nil"), "
              + "avatar: \(userInfo.profileImageURL?.prefix(60) ?? "nil")")
        #endif

        // Step 2: Fetch tweets via UserTweets
        let tweets = await fetchTweets(
            userId: userInfo.id, cookies: cookies
        )

        #if DEBUG
        print("[XProfileScraper] Fetched \(tweets.count) tweets total")
        #endif

        return XProfileScrapeResult(
            tweets: tweets,
            profileImageURL: userInfo.profileImageURL,
            displayName: userInfo.displayName
        )
    }

    // MARK: - API Calls

    private struct UserInfo {
        let id: String
        let displayName: String?
        let profileImageURL: String?
    }

    private struct XCookies {
        let csrfToken: String
        let authToken: String
    }

    /// Ensures the WKWebsiteDataStore cookie store is hydrated.
    /// Cookies live on disk but aren't visible via `allCookies()` until a
    /// WKWebView has loaded a page from the relevant domain in this process.
    @MainActor
    private static var cookieStoreWarmed = false

    @MainActor
    private static func warmCookieStoreIfNeeded() async {
        guard !cookieStoreWarmed else { return }
        cookieStoreWarmed = true

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)

        guard let url = URL(string: "https://x.com/settings") else { return }
        webView.load(URLRequest(url: url, timeoutInterval: 10))

        // Wait briefly for the cookie store to sync from disk
        try? await Task.sleep(for: .seconds(2))
    }

    @MainActor
    private static func getXCookies() async -> XCookies? {
        await warmCookieStoreIfNeeded()

        let store = WKWebsiteDataStore.default()
        let cookies = await store.httpCookieStore.allCookies()

        var csrfToken: String?
        var authToken: String?

        for cookie in cookies {
            let domain = cookie.domain.lowercased()
            guard domain.contains("x.com") || domain.contains("twitter.com") else { continue }
            if cookie.name == "ct0" { csrfToken = cookie.value }
            if cookie.name == "auth_token" { authToken = cookie.value }
        }

        guard let csrf = csrfToken, let auth = authToken else { return nil }
        return XCookies(csrfToken: csrf, authToken: auth)
    }

    private func buildRequest(
        url: URL, cookies: XCookies
    ) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: 15)
        let bearer = Self.bearerToken.removingPercentEncoding ?? Self.bearerToken
        request.setValue("Bearer \(bearer)", forHTTPHeaderField: "authorization")
        request.setValue(cookies.csrfToken, forHTTPHeaderField: "x-csrf-token")
        request.setValue("OAuth2Session", forHTTPHeaderField: "x-twitter-auth-type")
        request.setValue("yes", forHTTPHeaderField: "x-twitter-active-user")
        request.setValue("auth_token=\(cookies.authToken); ct0=\(cookies.csrfToken)",
                         forHTTPHeaderField: "cookie")
        return request
    }

    private func fetchUserInfo(
        screenName: String, cookies: XCookies
    ) async -> UserInfo? {
        let variables: [String: Any] = [
            "screen_name": screenName,
            "withGrokTranslatedBio": true
        ]
        let fieldToggles: [String: Any] = [
            "withPayments": false,
            "withAuxiliaryUserLabels": true
        ]

        guard let url = Self.buildGraphQLURL(
            queryID: Self.userByScreenNameQueryID,
            operationName: "UserByScreenName",
            variables: variables,
            features: Self.userByScreenNameFeatures,
            fieldToggles: fieldToggles
        ) else {
            #if DEBUG
            print("[XProfileScraper] Failed to build UserByScreenName URL")
            #endif
            return nil
        }

        let request = buildRequest(url: url, cookies: cookies)

        #if DEBUG
        print("[XProfileScraper] UserByScreenName request URL: \(url)")
        print("[XProfileScraper] Request headers: \(request.allHTTPHeaderFields ?? [:])")
        #endif

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            #if DEBUG
            print("[XProfileScraper] UserByScreenName network error: \(error)")
            #endif
            return nil
        }

        guard let httpResponse = response as? HTTPURLResponse else { return nil }

        #if DEBUG
        print("[XProfileScraper] UserByScreenName status: \(httpResponse.statusCode)")
        if let body = String(data: data, encoding: .utf8) {
            print("[XProfileScraper] UserByScreenName response: \(body.prefix(1000))")
        }
        #endif

        guard httpResponse.statusCode == 200 else { return nil }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let user = dataObj["user"] as? [String: Any],
              let result = user["result"] as? [String: Any] else {
            #if DEBUG
            print("[XProfileScraper] Failed to parse UserByScreenName JSON structure")
            #endif
            return nil
        }

        let restId = result["rest_id"] as? String ?? ""
        guard !restId.isEmpty else { return nil }

        // Display name and screen name are in result.core
        let core = result["core"] as? [String: Any]
        let displayName = core?["name"] as? String

        // Profile image is in result.avatar
        let avatar = result["avatar"] as? [String: Any]
        var profileImageURL = avatar?["image_url"] as? String

        // Upgrade to high-res version
        if let url = profileImageURL {
            profileImageURL = url
                .replacingOccurrences(of: "_normal.", with: "_400x400.")
                .replacingOccurrences(of: "_bigger.", with: "_400x400.")
                .replacingOccurrences(of: "_mini.", with: "_400x400.")
                .replacingOccurrences(of: "_200x200.", with: "_400x400.")
        }

        return UserInfo(
            id: restId,
            displayName: displayName,
            profileImageURL: profileImageURL
        )
    }

    private func fetchTweets(
        userId: String, cookies: XCookies
    ) async -> [ParsedTweet] {
        var allTweets: [ParsedTweet] = []
        var seenIDs = Set<String>()
        var cursor: String?

        // Fetch up to 2 pages to reach targetTweetCount
        for page in 0..<2 {
            guard !Task.isCancelled else { break }

            var variables: [String: Any] = [
                "userId": userId,
                "count": 40,
                "includePromotedContent": false,
                "withQuickPromoteEligibilityTweetFields": true,
                "withVoice": true
            ]
            if let cursor {
                variables["cursor"] = cursor
            }

            let fieldToggles: [String: Any] = ["withArticlePlainText": false]

            guard let url = Self.buildGraphQLURL(
                queryID: Self.userTweetsQueryID,
                operationName: "UserTweets",
                variables: variables,
                features: Self.userTweetsFeatures,
                fieldToggles: fieldToggles
            ) else {
                #if DEBUG
                print("[XProfileScraper] Failed to build UserTweets URL (page \(page))")
                #endif
                break
            }

            let request = buildRequest(url: url, cookies: cookies)

            #if DEBUG
            print("[XProfileScraper] UserTweets request (page \(page)): \(url)")
            #endif

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await URLSession.shared.data(for: request)
            } catch {
                #if DEBUG
                print("[XProfileScraper] UserTweets network error (page \(page)): \(error)")
                #endif
                break
            }

            guard let httpResponse = response as? HTTPURLResponse else { break }

            #if DEBUG
            print("[XProfileScraper] UserTweets status (page \(page)): "
                  + "\(httpResponse.statusCode)")
            if let body = String(data: data, encoding: .utf8) {
                print("[XProfileScraper] UserTweets response (page \(page)): "
                      + "\(body.prefix(2000))")
            }
            #endif

            guard httpResponse.statusCode == 200 else { break }

            guard let parsed = Self.parseTweetsResponse(data: data) else {
                #if DEBUG
                print("[XProfileScraper] Failed to parse UserTweets response (page \(page))")
                #endif
                break
            }

            #if DEBUG
            print("[XProfileScraper] Parsed \(parsed.tweets.count) tweets from page \(page), "
                  + "cursor: \(parsed.bottomCursor?.prefix(30) ?? "nil")")
            #endif

            var newCount = 0
            for tweet in parsed.tweets where !seenIDs.contains(tweet.id) {
                seenIDs.insert(tweet.id)
                allTweets.append(tweet)
                newCount += 1
            }

            if newCount == 0 || allTweets.count >= Self.targetTweetCount { break }
            cursor = parsed.bottomCursor
            if cursor == nil { break }
        }

        return allTweets
    }

    // MARK: - Static Helpers

    /// Returns true if the URL points to an X/Twitter profile.
    nonisolated static func isXProfileURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let isXDomain = host == "x.com" || host == "twitter.com"
            || host == "www.x.com" || host == "www.twitter.com"
            || host == "mobile.x.com" || host == "mobile.twitter.com"
        guard isXDomain else { return false }

        let path = url.path
        guard path.count > 1 else { return false }

        let handle = String(path.dropFirst())
            .split(separator: "/").first.map(String.init) ?? ""
        guard !handle.isEmpty else { return false }

        let reserved: Set<String> = [
            "home", "explore", "search", "notifications", "messages",
            "settings", "login", "signup", "i", "intent", "hashtag",
            "compose", "tos", "privacy"
        ]
        return !reserved.contains(handle.lowercased())
    }

    /// Extracts the username handle from an X profile URL.
    nonisolated static func extractHandle(from url: URL) -> String? {
        let path = url.path
        guard path.count > 1 else { return nil }
        return path.dropFirst()
            .split(separator: "/").first
            .map(String.init)
    }

    /// Constructs a canonical X profile URL from a handle.
    nonisolated static func profileURL(for handle: String) -> URL? {
        URL(string: "https://x.com/\(handle)")
    }

    /// The pseudo-feed URL stored in the database for an X profile.
    nonisolated static func feedURL(for handle: String) -> String {
        "x-profile://\(handle.lowercased())"
    }

    /// Checks if a feed URL is an X pseudo-feed.
    nonisolated static func isXFeedURL(_ url: String) -> Bool {
        url.hasPrefix("x-profile://")
    }

    /// Extracts the handle from an X pseudo-feed URL.
    nonisolated static func handleFromFeedURL(_ url: String) -> String? {
        guard isXFeedURL(url) else { return nil }
        return String(url.dropFirst("x-profile://".count))
    }

    /// Checks if the user has X cookies (i.e. is logged in).
    @MainActor
    static func hasXSession() async -> Bool {
        let store = WKWebsiteDataStore.default()
        let cookies = await store.httpCookieStore.allCookies()
        return cookies.contains { cookie in
            let domain = cookie.domain.lowercased()
            return (domain.contains("x.com") || domain.contains("twitter.com"))
                && (cookie.name == "auth_token" || cookie.name == "ct0")
        }
    }

    /// Clears X session cookies.
    @MainActor
    static func clearXSession() async {
        let store = WKWebsiteDataStore.default()
        let cookies = await store.httpCookieStore.allCookies()
        for cookie in cookies where cookie.domain.lowercased().contains("x.com")
            || cookie.domain.lowercased().contains("twitter.com") {
            await store.httpCookieStore.deleteCookie(cookie)
        }
    }
}
