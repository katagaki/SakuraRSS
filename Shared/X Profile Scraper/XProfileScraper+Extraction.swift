import Foundation

// MARK: - API Configuration & Response Parsing

extension XProfileScraper {

    // swiftlint:disable line_length
    static let userTweetsFeatures: [String: Bool] = [
        "rweb_video_screen_enabled": false,
        "profile_label_improvements_pcf_label_in_post_enabled": true,
        "responsive_web_profile_redirect_enabled": false,
        "rweb_tipjar_consumption_enabled": false,
        "verified_phone_label_enabled": false,
        "creator_subscriptions_tweet_preview_api_enabled": true,
        "responsive_web_graphql_timeline_navigation_enabled": true,
        "responsive_web_graphql_skip_user_profile_image_extensions_enabled": false,
        "premium_content_api_read_enabled": false,
        "communities_web_enable_tweet_community_results_fetch": true,
        "c9s_tweet_anatomy_moderator_badge_enabled": true,
        "responsive_web_grok_analyze_button_fetch_trends_enabled": false,
        "responsive_web_grok_analyze_post_followups_enabled": true,
        "responsive_web_jetfuel_frame": true,
        "responsive_web_grok_share_attachment_enabled": true,
        "responsive_web_grok_annotations_enabled": true,
        "articles_preview_enabled": true,
        "responsive_web_edit_tweet_api_enabled": true,
        "graphql_is_translatable_rweb_tweet_is_translatable_enabled": true,
        "view_counts_everywhere_api_enabled": true,
        "longform_notetweets_consumption_enabled": true,
        "responsive_web_twitter_article_tweet_consumption_enabled": true,
        "content_disclosure_indicator_enabled": true,
        "content_disclosure_ai_generated_indicator_enabled": true,
        "responsive_web_grok_show_grok_translated_post": true,
        "responsive_web_grok_analysis_button_from_backend": true,
        "post_ctas_fetch_enabled": false,
        "freedom_of_speech_not_reach_fetch_enabled": true,
        "standardized_nudges_misinfo": true,
        "tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled": true,
        "longform_notetweets_rich_text_read_enabled": true,
        "longform_notetweets_inline_media_enabled": false,
        "responsive_web_grok_image_annotation_enabled": true,
        "responsive_web_grok_imagine_annotation_enabled": true,
        "responsive_web_grok_community_note_auto_translation_is_enabled": false,
        "responsive_web_enhance_cards_enabled": false
    ]
    // swiftlint:enable line_length

    struct TweetsPage {
        let tweets: [ParsedTweet]
        let bottomCursor: String?
    }

    static func parseTweetsResponse(data: Data) -> TweetsPage? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let user = dataObj["user"] as? [String: Any],
              let result = user["result"] as? [String: Any],
              let timeline = result["timeline"] as? [String: Any],
              let innerTimeline = timeline["timeline"] as? [String: Any],
              let instructions = innerTimeline["instructions"] as? [[String: Any]] else {
            return nil
        }

        guard let addEntries = instructions.first(
            where: { ($0["type"] as? String) == "TimelineAddEntries" }
        ), let entries = addEntries["entries"] as? [[String: Any]] else {
            return nil
        }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "EEE MMM dd HH:mm:ss Z yyyy"

        var tweets: [ParsedTweet] = []
        var bottomCursor: String?

        for entry in entries {
            guard let content = entry["content"] as? [String: Any] else { continue }
            let entryType = content["entryType"] as? String

            if entryType == "TimelineTimelineCursor" {
                if (content["cursorType"] as? String) == "Bottom" {
                    bottomCursor = content["value"] as? String
                }
                continue
            }

            guard entryType == "TimelineTimelineItem" else { continue }

            if let tweet = parseTweetEntry(content: content, dateFormatter: dateFormatter) {
                tweets.append(tweet)
            }
        }

        return TweetsPage(tweets: tweets, bottomCursor: bottomCursor)
    }

    private static func parseTweetEntry(
        content: [String: Any], dateFormatter: DateFormatter
    ) -> ParsedTweet? {
        guard let itemContent = content["itemContent"] as? [String: Any],
              let tweetResults = itemContent["tweet_results"] as? [String: Any],
              let tweetResult = tweetResults["result"] as? [String: Any] else {
            return nil
        }

        // Handle TweetWithVisibilityResults wrapper
        let actualResult: [String: Any]
        if (tweetResult["__typename"] as? String) == "TweetWithVisibilityResults",
           let tweet = tweetResult["tweet"] as? [String: Any] {
            actualResult = tweet
        } else {
            actualResult = tweetResult
        }

        guard let legacy = actualResult["legacy"] as? [String: Any] else { return nil }

        // Skip retweets
        if legacy["retweeted_status_result"] != nil { return nil }

        let fullText = legacy["full_text"] as? String ?? ""
        let idStr = legacy["id_str"] as? String ?? ""
        let createdAt = legacy["created_at"] as? String ?? ""

        guard !idStr.isEmpty else { return nil }

        // Author info from core.user_results.result
        let core = actualResult["core"] as? [String: Any]
        let userResults = core?["user_results"] as? [String: Any]
        let userResult = userResults?["result"] as? [String: Any]
        let userCore = userResult?["core"] as? [String: Any]
        let authorName = userCore?["name"] as? String ?? ""
        let authorHandle = userCore?["screen_name"] as? String ?? ""

        // First media image
        let extendedEntities = legacy["extended_entities"] as? [String: Any]
        let media = extendedEntities?["media"] as? [[String: Any]]
        let firstImage = media?.first(where: { ($0["type"] as? String) == "photo" })
        let imageURL = firstImage?["media_url_https"] as? String

        let publishedDate = dateFormatter.date(from: createdAt)
        let tweetURL = "https://x.com/\(authorHandle)/status/\(idStr)"

        // Clean full_text: remove trailing t.co URLs
        let cleanText = fullText.replacingOccurrences(
            of: "\\s*https://t\\.co/\\S+$",
            with: "",
            options: .regularExpression
        )

        return ParsedTweet(
            id: idStr,
            text: cleanText,
            author: authorName,
            authorHandle: authorHandle,
            url: tweetURL,
            imageURL: imageURL,
            publishedDate: publishedDate
        )
    }

    // MARK: - URL Building

    static func buildGraphQLURL(
        queryID: String,
        operationName: String,
        variables: [String: Any],
        features: [String: Bool],
        fieldToggles: [String: Any]? = nil
    ) -> URL? {
        guard let variablesJSON = try? JSONSerialization.data(withJSONObject: variables),
              let variablesString = String(data: variablesJSON, encoding: .utf8),
              let featuresJSON = try? JSONSerialization.data(withJSONObject: features),
              let featuresString = String(data: featuresJSON, encoding: .utf8) else {
            return nil
        }

        var components = URLComponents(
            string: "https://x.com/i/api/graphql/\(queryID)/\(operationName)"
        )
        var queryItems = [
            URLQueryItem(name: "variables", value: variablesString),
            URLQueryItem(name: "features", value: featuresString)
        ]

        if let fieldToggles,
           let togglesJSON = try? JSONSerialization.data(withJSONObject: fieldToggles),
           let togglesString = String(data: togglesJSON, encoding: .utf8) {
            queryItems.append(URLQueryItem(name: "fieldToggles", value: togglesString))
        }

        components?.queryItems = queryItems
        return components?.url
    }
}
