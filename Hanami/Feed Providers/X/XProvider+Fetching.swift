import Foundation

// MARK: - API Fetching

public extension XProvider {

    struct UserInfo {
        public let id: String
        public let displayName: String?
        public let profileImageURL: String?
    }

    struct XCookies {
        public let csrfToken: String
        public let authToken: String
    }

    func performFetch(
        profileURL: URL,
        autoRepairQueryIDs: Bool = true
    ) async -> XProfileFetchResult {
        guard let handle = Self.extractIdentifier(from: profileURL) else {
            log("XProvider", "Failed to extract handle from URL: \(profileURL)")
            return XProfileFetchResult(tweets: [], profileImageURL: nil, displayName: nil)
        }

        log("XProvider", "Fetching profile for handle: \(handle)")

        guard let cookies = await Self.getXCookies(autoRepair: autoRepairQueryIDs) else {
            log("XProvider", "No X session cookies found")
            return XProfileFetchResult(tweets: [], profileImageURL: nil, displayName: nil)
        }

        log("XProvider", "Got cookies - csrf: \(cookies.csrfToken.prefix(5))…")

        guard let userInfo = await fetchUserInfo(
            screenName: handle, cookies: cookies
        ) else {
            log("XProvider", "Failed to fetch user info for \(handle)")
            return XProfileFetchResult(tweets: [], profileImageURL: nil, displayName: nil)
        }

        // swiftlint:disable:next line_length
        log("XProvider", "User info - id: \(userInfo.id), name: \(userInfo.displayName ?? "nil"), avatar: \(userInfo.profileImageURL?.prefix(60) ?? "nil")")

        let tweets = await fetchTweets(
            userId: userInfo.id, cookies: cookies
        )

        log("XProvider", "Fetched \(tweets.count) tweets total")

        Self.persistRotatedCookies()

        return XProfileFetchResult(
            tweets: tweets,
            profileImageURL: userInfo.profileImageURL,
            displayName: userInfo.displayName
        )
    }

    // MARK: - Cookies

    /// Reads the current X session and ensures GraphQL query IDs are loaded.
    /// Pass `autoRepair: false` from background contexts where fetching x.com
    /// to discover query IDs would blow the BG task budget.
    @MainActor
    static func getXCookies(autoRepair: Bool = true) async -> XCookies? {
        if autoRepair {
            await fetchQueryIDsIfNeeded()
        }
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

    func fetchUserInfo(
        screenName: String, cookies: XCookies
    ) async -> UserInfo? {
        guard let request = buildUserByScreenNameRequest(
            screenName: screenName, cookies: cookies
        ) else { return nil }
        log("XProvider", "Request headers: \(request.allHTTPHeaderFields ?? [:])")

        guard let result = await fetchUserByScreenNameResult(request: request) else { return nil }

        let restId = result["rest_id"] as? String ?? ""
        guard !restId.isEmpty else { return nil }

        let core = result["core"] as? [String: Any]
        let displayName = core?["name"] as? String

        let avatar = result["avatar"] as? [String: Any]
        let profileImageURL = upscaleAvatarURL(avatar?["image_url"] as? String)

        return UserInfo(
            id: restId,
            displayName: displayName,
            profileImageURL: profileImageURL
        )
    }

    private func buildUserByScreenNameRequest(
        screenName: String, cookies: XCookies
    ) -> URLRequest? {
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
            log("XProvider", "Failed to build UserByScreenName URL")
            return nil
        }
        log("XProvider", "UserByScreenName request URL: \(url)")
        return buildRequest(url: url, cookies: cookies)
    }

    private func fetchUserByScreenNameResult(request: URLRequest) async -> [String: Any]? {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            log("XProvider", "UserByScreenName network error: \(error)")
            return nil
        }
        guard let httpResponse = response as? HTTPURLResponse else { return nil }
        log("XProvider", "UserByScreenName status: \(httpResponse.statusCode)")
        if let body = String(data: data, encoding: .utf8) {
            log("XProvider", "UserByScreenName response: \(body.prefix(1000))")
        }
        guard httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let user = dataObj["user"] as? [String: Any],
              let result = user["result"] as? [String: Any] else {
            log("XProvider", "Failed to parse UserByScreenName JSON structure")
            return nil
        }
        return result
    }

    private func upscaleAvatarURL(_ url: String?) -> String? {
        guard let url else { return nil }
        return url
            .replacingOccurrences(of: "_normal.", with: "_400x400.")
            .replacingOccurrences(of: "_bigger.", with: "_400x400.")
            .replacingOccurrences(of: "_mini.", with: "_400x400.")
            .replacingOccurrences(of: "_200x200.", with: "_400x400.")
    }

    // MARK: - Single Tweet

    /// Fetches a single tweet via the TweetResultByRestId GraphQL endpoint.
    /// Preferred over TweetDetail for embeds because the response preserves
    /// note_tweet text for longform posts (TweetDetail returns the truncated
    /// legacy.full_text instead).
    func fetchSingleTweet(tweetID: String) async -> ParsedTweet? {
        await fetchTweetResultByRestId(tweetID: tweetID)
    }

    /// Fetches a single tweet via the TweetResultByRestId GraphQL endpoint.
    /// On a stale-query-ID failure, re-extracts query IDs from the current
    /// x.com bundle once and retries.
    func fetchTweetResultByRestId(tweetID: String) async -> ParsedTweet? {
        if let data = await performTweetResultByRestIdFetch(tweetID: tweetID),
           Self.tweetResultByRestIdHasResult(data) {
            return Self.parseTweetResultByRestIdResponse(data: data)
        }
        log("XProvider", "TweetResultByRestId failed; refreshing query IDs and retrying tweet=\(tweetID)")
        await MainActor.run { Self.queryIDsFetched = false }
        await Self.fetchQueryIDsIfNeeded()
        guard let data = await performTweetResultByRestIdFetch(tweetID: tweetID) else {
            return nil
        }
        return Self.parseTweetResultByRestIdResponse(data: data)
    }

    private func performTweetResultByRestIdFetch(tweetID: String) async -> Data? {
        guard let cookies = await Self.getXCookies() else {
            log("XProvider", "No X session cookies for TweetResultByRestId fetch")
            return nil
        }

        let variables: [String: Any] = [
            "tweetId": tweetID,
            "includePromotedContent": true,
            "withBirdwatchNotes": true,
            "withVoice": true,
            "withCommunity": true
        ]

        let fieldToggles: [String: Any] = [
            "withArticleRichContentState": true,
            "withArticlePlainText": false,
            "withArticleSummaryText": true,
            "withArticleVoiceOver": true
        ]

        guard let queryID = Self.tweetResultByRestIdQueryID,
              let url = Self.buildGraphQLURL(
                queryID: queryID,
                operationName: "TweetResultByRestId",
                variables: variables,
                features: Self.tweetResultByRestIdFeatures,
                fieldToggles: fieldToggles
              ) else {
            log("XProvider", "Failed to build TweetResultByRestId URL")
            return nil
        }

        let request = buildRequest(url: url, cookies: cookies)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            log("XProvider", "TweetResultByRestId network error: \(error)")
            return nil
        }

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            log("XProvider", "TweetResultByRestId bad status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            return nil
        }

        return data
    }

    /// Returns true if the response actually contains the tweet payload.
    /// A 200 with `errors` (e.g. when the query ID has rotated) lacks this.
    private static func tweetResultByRestIdHasResult(_ data: Data) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let tweetResult = dataObj["tweetResult"] as? [String: Any],
              tweetResult["result"] is [String: Any] else {
            return false
        }
        return true
    }

    /// Fetches the focal tweet plus any consecutive same-author tweets that
    /// share its TimelineTimelineModule (self-thread). Per-tweet images and
    /// quote-tweet URLs are returned in display order. The focal tweet's body
    /// is overridden with the longform note_tweet text from TweetResultByRestId
    /// when available, since TweetDetail returns the truncated legacy.full_text.
    func fetchTweetContent(tweetID: String) async -> ParsedTweetContent? {
        async let detailDataTask = fetchTweetDetailData(tweetID: tweetID)
        async let longformTask = fetchTweetResultByRestId(tweetID: tweetID)

        guard let data = await detailDataTask,
              let content = Self.parseTweetDetailContent(data: data, tweetID: tweetID)
        else { return nil }

        guard let longform = await longformTask,
              longform.id == tweetID,
              let focalIdx = content.threadItems.firstIndex(where: { $0.id == tweetID }),
              longform.text.count > content.threadItems[focalIdx].text.count
        else {
            return content
        }

        var items = content.threadItems
        let original = items[focalIdx]
        items[focalIdx] = ParsedThreadItem(
            id: original.id,
            text: longform.text,
            imageURLs: original.imageURLs,
            quotedTweetURL: original.quotedTweetURL
        )
        return ParsedTweetContent(focal: content.focal, threadItems: items)
    }

    func performTweetDetailFetch(tweetID: String) async -> Data? {
        guard let cookies = await Self.getXCookies() else {
            log("XProvider", "No X session cookies for TweetDetail fetch")
            return nil
        }
        guard let url = buildTweetDetailURL(tweetID: tweetID) else { return nil }
        let request = buildRequest(url: url, cookies: cookies)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            log("XProvider", "TweetDetail network error: \(error)")
            return nil
        }

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            log("XProvider", "TweetDetail bad status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            return nil
        }

        if let json = String(data: data, encoding: .utf8) {
            log("XProvider", "TweetDetail JSON tweet=\(tweetID): \(json)")
        }

        return data
    }

    private func buildTweetDetailURL(tweetID: String) -> URL? {
        // Mirrors the variables/features/fieldToggles the x.com web client
        // currently sends for the relevance-ranked TweetDetail call.
        let variables: [String: Any] = [
            "focalTweetId": tweetID,
            "referrer": "tweet",
            "with_rux_injections": false,
            "rankingMode": "Relevance",
            "includePromotedContent": true,
            "withCommunity": true,
            "withQuickPromoteEligibilityTweetFields": true,
            "withBirdwatchNotes": true,
            "withVoice": true
        ]
        let fieldToggles: [String: Any] = [
            "withArticleRichContentState": true,
            "withArticlePlainText": false,
            "withArticleSummaryText": true,
            "withArticleVoiceOver": true,
            "withGrokAnalyze": false,
            "withDisallowedReplyControls": false
        ]
        guard let queryID = Self.tweetDetailQueryID,
              let url = Self.buildGraphQLURL(
                queryID: queryID,
                operationName: "TweetDetail",
                variables: variables,
                features: Self.tweetDetailFeatures,
                fieldToggles: fieldToggles
              ) else {
            log("XProvider", "Failed to build TweetDetail URL")
            return nil
        }
        return url
    }

}
