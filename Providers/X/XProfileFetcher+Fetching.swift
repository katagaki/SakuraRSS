import Foundation

// MARK: - API Fetching

extension XProfileFetcher {

    struct UserInfo {
        let id: String
        let displayName: String?
        let profileImageURL: String?
    }

    struct XCookies {
        let csrfToken: String
        let authToken: String
    }

    func performFetch(profileURL: URL) async -> XProfileFetchResult {
        guard let handle = Self.extractIdentifier(from: profileURL) else {
            log("XProfileFetcher", "Failed to extract handle from URL: \(profileURL)")
            return XProfileFetchResult(tweets: [], profileImageURL: nil, displayName: nil)
        }

        log("XProfileFetcher", "Fetching profile for handle: \(handle)")

        guard let cookies = await Self.getXCookies() else {
            log("XProfileFetcher", "No X session cookies found")
            return XProfileFetchResult(tweets: [], profileImageURL: nil, displayName: nil)
        }

        log("XProfileFetcher", "Got cookies - csrf: \(cookies.csrfToken.prefix(20))…")

        guard let userInfo = await fetchUserInfo(
            screenName: handle, cookies: cookies
        ) else {
            log("XProfileFetcher", "Failed to fetch user info for \(handle)")
            return XProfileFetchResult(tweets: [], profileImageURL: nil, displayName: nil)
        }

        // swiftlint:disable:next line_length
        log("XProfileFetcher", "User info - id: \(userInfo.id), name: \(userInfo.displayName ?? "nil"), avatar: \(userInfo.profileImageURL?.prefix(60) ?? "nil")")

        let tweets = await fetchTweets(
            userId: userInfo.id, cookies: cookies
        )

        log("XProfileFetcher", "Fetched \(tweets.count) tweets total")

        // Persist any cookies X rotated during the fetch.
        Self.persistRotatedCookies()

        return XProfileFetchResult(
            tweets: tweets,
            profileImageURL: userInfo.profileImageURL,
            displayName: userInfo.displayName
        )
    }

    // MARK: - Cookies

    /// Reads the current X session and ensures GraphQL query IDs are loaded.
    @MainActor
    static func getXCookies() async -> XCookies? {
        await fetchQueryIDsIfNeeded()
        return readXCookiesFromKeychain()
    }

    static func readXCookiesFromKeychain() -> XCookies? {
        guard let cookies = cookieStore.load() else { return nil }

        var csrfToken: String?
        var authToken: String?

        for cookie in cookies {
            if cookie.name == "ct0" { csrfToken = cookie.value }
            if cookie.name == "auth_token" { authToken = cookie.value }
        }

        guard let csrf = csrfToken, let auth = authToken else { return nil }
        return XCookies(csrfToken: csrf, authToken: auth)
    }

    /// Writes rotated X cookies from `HTTPCookieStorage.shared` back to Keychain.
    static func persistRotatedCookies() {
        let jar = HTTPCookieStorage.shared
        let xCookies = (jar.cookies ?? []).filter {
            let domain = $0.domain.lowercased()
            return domain.contains("x.com") || domain.contains("twitter.com")
        }
        guard !xCookies.isEmpty else { return }
        cookieStore.save(xCookies)
    }

    // MARK: - Request Building

    func buildRequest(
        url: URL, cookies: XCookies
    ) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: requestTimeoutInterval)
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

    // swiftlint:disable:next function_body_length
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
            log("XProfileFetcher", "Failed to build UserByScreenName URL")
            return nil
        }

        let request = buildRequest(url: url, cookies: cookies)

        log("XProfileFetcher", "UserByScreenName request URL: \(url)")
        log("XProfileFetcher", "Request headers: \(request.allHTTPHeaderFields ?? [:])")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            log("XProfileFetcher", "UserByScreenName network error: \(error)")
            return nil
        }

        guard let httpResponse = response as? HTTPURLResponse else { return nil }

        log("XProfileFetcher", "UserByScreenName status: \(httpResponse.statusCode)")
        if let body = String(data: data, encoding: .utf8) {
            log("XProfileFetcher", "UserByScreenName response: \(body.prefix(1000))")
        }

        guard httpResponse.statusCode == 200 else { return nil }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let user = dataObj["user"] as? [String: Any],
              let result = user["result"] as? [String: Any] else {
            log("XProfileFetcher", "Failed to parse UserByScreenName JSON structure")
            return nil
        }

        let restId = result["rest_id"] as? String ?? ""
        guard !restId.isEmpty else { return nil }

        let core = result["core"] as? [String: Any]
        let displayName = core?["name"] as? String

        let avatar = result["avatar"] as? [String: Any]
        var profileImageURL = avatar?["image_url"] as? String

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

    /// Fetches a single tweet via the TweetDetail GraphQL endpoint.
    func fetchSingleTweet(tweetID: String) async -> ParsedTweet? {
        guard let cookies = await Self.getXCookies() else {
            log("XProfileFetcher", "No X session cookies for single tweet fetch")
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
            log("XProfileFetcher", "Failed to build TweetDetail URL")
            return nil
        }

        let request = buildRequest(url: url, cookies: cookies)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            log("XProfileFetcher", "TweetDetail network error: \(error)")
            return nil
        }

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            log("XProfileFetcher", "TweetDetail bad status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
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
                log("XProfileFetcher", "Failed to build UserTweets URL (page \(page))")
                break
            }

            let request = buildRequest(url: url, cookies: cookies)

            log("XProfileFetcher", "UserTweets request (page \(page)): \(url)")

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await URLSession.shared.data(for: request)
            } catch {
                log("XProfileFetcher", "UserTweets network error (page \(page)): \(error)")
                break
            }

            guard let httpResponse = response as? HTTPURLResponse else { break }

            log("XProfileFetcher", "UserTweets status (page \(page)): \(httpResponse.statusCode)")
            if let body = String(data: data, encoding: .utf8) {
                log("XProfileFetcher", "UserTweets response (page \(page)): \(body.prefix(2000))")
            }

            guard httpResponse.statusCode == 200 else { break }

            guard let parsed = Self.parseTweetsResponse(data: data) else {
                log("XProfileFetcher", "Failed to parse UserTweets response (page \(page))")
                break
            }

            // swiftlint:disable:next line_length
            log("XProfileFetcher", "Parsed \(parsed.tweets.count) tweets from page \(page), cursor: \(parsed.bottomCursor?.prefix(30) ?? "nil")")

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
