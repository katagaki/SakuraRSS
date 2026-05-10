import Foundation

public extension XProvider {

    // MARK: - Tweets

    func fetchTweets(
        userId: String, cookies: XCookies
    ) async -> [ParsedTweet] {
        var allTweets: [ParsedTweet] = []
        var seenIDs = Set<String>()
        var cursor: String?

        for page in 0..<2 {
            guard !Task.isCancelled else { break }
            guard let request = buildUserTweetsRequest(
                userId: userId, cursor: cursor, cookies: cookies, page: page
            ) else { break }

            log("XProvider", "UserTweets request (page \(page))")
            guard let parsed = await fetchAndParseTweetsPage(request: request, page: page) else {
                break
            }

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

    private func buildUserTweetsRequest(
        userId: String, cursor: String?, cookies: XCookies, page: Int
    ) -> URLRequest? {
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
            log("XProvider", "Failed to build UserTweets URL (page \(page))")
            return nil
        }
        return buildRequest(url: url, cookies: cookies)
    }

    private func fetchAndParseTweetsPage(
        request: URLRequest, page: Int
    ) async -> TweetsPage? {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            log("XProvider", "UserTweets network error (page \(page)): \(error)")
            return nil
        }
        guard let httpResponse = response as? HTTPURLResponse else { return nil }
        log("XProvider", "UserTweets status (page \(page)): \(httpResponse.statusCode)")
        if let body = String(data: data, encoding: .utf8) {
            log("XProvider", "UserTweets response (page \(page)): \(body.prefix(2000))")
        }
        guard httpResponse.statusCode == 200,
              let parsed = Self.parseTweetsResponse(data: data) else {
            log("XProvider", "Failed to parse UserTweets response (page \(page))")
            return nil
        }
        // swiftlint:disable:next line_length
        log("XProvider", "Parsed \(parsed.tweets.count) tweets from page \(page), cursor: \(parsed.bottomCursor?.prefix(30) ?? "nil")")
        return parsed
    }
}
