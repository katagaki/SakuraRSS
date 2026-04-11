import Foundation
import WebKit

// MARK: - API Fetching

extension XProfileScraper {

    struct UserInfo {
        let id: String
        let displayName: String?
        let profileImageURL: String?
    }

    struct XCookies {
        let csrfToken: String
        let authToken: String
    }

    func performFetch(profileURL: URL) async -> XProfileScrapeResult {
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

    // MARK: - Cookies

    @MainActor
    static func getXCookies() async -> XCookies? {
        await fetchQueryIDsIfNeeded()

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

    // MARK: - Request Building

    func buildRequest(
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
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    // MARK: - User Info

    func fetchUserInfo(
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

        guard let queryID = Self.userByScreenNameQueryID,
              let url = Self.buildGraphQLURL(
            queryID: queryID,
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

    // MARK: - Single Tweet

    /// Fetches a single tweet by its ID using the TweetDetail GraphQL endpoint.
    /// Returns the parsed tweet, or nil if the fetch fails.
    func fetchSingleTweet(tweetID: String) async -> ParsedTweet? {
        guard let cookies = await Self.getXCookies() else {
            #if DEBUG
            print("[XProfileScraper] No X session cookies for single tweet fetch")
            #endif
            return nil
        }

        let variables: [String: Any] = [
            "focalTweetId": tweetID,
            "with_rux_injections": false,
            "rankingMode": "Relevance",
            "includePromotedContent": false,
            "withCommunity": true,
            "withQuickPromoteEligibilityTweetFields": true,
            "withBirdwatchNotes": true,
            "withVoice": true
        ]

        guard let queryID = Self.tweetDetailQueryID,
              let url = Self.buildGraphQLURL(
                queryID: queryID,
                operationName: "TweetDetail",
                variables: variables,
                features: Self.userTweetsFeatures,
                fieldToggles: ["withArticlePlainText": false]
              ) else {
            #if DEBUG
            print("[XProfileScraper] Failed to build TweetDetail URL")
            #endif
            return nil
        }

        let request = buildRequest(url: url, cookies: cookies)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            #if DEBUG
            print("[XProfileScraper] TweetDetail network error: \(error)")
            #endif
            return nil
        }

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            #if DEBUG
            print("[XProfileScraper] TweetDetail bad status: "
                  + "\((response as? HTTPURLResponse)?.statusCode ?? -1)")
            #endif
            return nil
        }

        return Self.parseTweetDetailResponse(data: data, tweetID: tweetID)
    }

    // MARK: - Tweets

    func fetchTweets(
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

            guard let queryID = Self.userTweetsQueryID,
                  let url = Self.buildGraphQLURL(
                queryID: queryID,
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
}
