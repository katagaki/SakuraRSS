import Foundation

// MARK: - API Configuration & Response Parsing

extension XProfileFetcher {

    /// Feature flags x.com sends for the relevance-ranked TweetDetail call.
    /// Diverges from `userTweetsFeatures` in a couple of toggles (notably
    /// `rweb_cashtags_enabled` and the grok community-note flag), so kept
    /// separate to mirror the web client byte-for-byte.
    static let tweetDetailFeatures: [String: Bool] = [
        "rweb_video_screen_enabled": false,
        "rweb_cashtags_enabled": true,
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
        "responsive_web_grok_community_note_auto_translation_is_enabled": true,
        "responsive_web_enhance_cards_enabled": false
    ]

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

    // swiftlint:disable:next function_body_length
    private static func parseTweetEntry(
        content: [String: Any], dateFormatter: DateFormatter
    ) -> ParsedTweet? {
        guard let itemContent = content["itemContent"] as? [String: Any],
              let tweetResults = itemContent["tweet_results"] as? [String: Any],
              let tweetResult = tweetResults["result"] as? [String: Any] else {
            return nil
        }

        let actualResult: [String: Any]
        if (tweetResult["__typename"] as? String) == "TweetWithVisibilityResults",
           let tweet = tweetResult["tweet"] as? [String: Any] {
            actualResult = tweet
        } else {
            actualResult = tweetResult
        }

        guard let legacy = actualResult["legacy"] as? [String: Any] else { return nil }

        if legacy["retweeted_status_result"] != nil { return nil }

        let fullText = legacy["full_text"] as? String ?? ""
        let idStr = legacy["id_str"] as? String ?? ""
        let createdAt = legacy["created_at"] as? String ?? ""

        guard !idStr.isEmpty else { return nil }

        let core = actualResult["core"] as? [String: Any]
        let userResults = core?["user_results"] as? [String: Any]
        let userResult = userResults?["result"] as? [String: Any]
        let userCore = userResult?["core"] as? [String: Any]
        let authorName = userCore?["name"] as? String ?? ""
        let authorHandle = userCore?["screen_name"] as? String ?? ""

        let extendedEntities = legacy["extended_entities"] as? [String: Any]
        let media = extendedEntities?["media"] as? [[String: Any]]
        let photoURLs = media?
            .filter { ($0["type"] as? String) == "photo" }
            .compactMap { $0["media_url_https"] as? String } ?? []
        let imageURL = photoURLs.first

        let publishedDate = dateFormatter.date(from: createdAt)
        let tweetURL = "https://x.com/\(authorHandle)/status/\(idStr)"

        var cleanText = fullText
        let entities = legacy["entities"] as? [String: Any]
        if let urlEntities = entities?["urls"] as? [[String: Any]] {
            for urlEntity in urlEntities {
                guard let shortURL = urlEntity["url"] as? String,
                      let expandedURL = urlEntity["expanded_url"] as? String
                else { continue }
                cleanText = cleanText.replacingOccurrences(of: shortURL, with: expandedURL)
            }
        }

        // Strip trailing t.co media links that have no expanded form.
        cleanText = cleanText.replacingOccurrences(
            of: "\\s*https://t\\.co/\\S+$",
            with: "",
            options: .regularExpression
        )
        cleanText = XCommentText.decodeHTMLEntities(cleanText)

        return ParsedTweet(
            id: idStr,
            text: cleanText,
            author: authorName,
            authorHandle: authorHandle,
            url: tweetURL,
            imageURL: imageURL,
            carouselImageURLs: photoURLs.count > 1 ? photoURLs : [],
            publishedDate: publishedDate
        )
    }

    // MARK: - TweetDetail Response Parsing

    static func parseTweetDetailResponse(data: Data, tweetID: String) -> ParsedTweet? {
        guard let entries = tweetDetailEntries(from: data) else { return nil }
        let dateFormatter = makeXDateFormatter()

        for entry in entries {
            guard let content = entry["content"] as? [String: Any] else { continue }
            let entryType = content["entryType"] as? String

            if entryType == "TimelineTimelineItem" {
                if let tweet = parseTweetEntry(content: content,
                                               dateFormatter: dateFormatter),
                   tweet.id == tweetID {
                    return tweet
                }
            } else if entryType == "TimelineTimelineModule" {
                guard let items = content["items"] as? [[String: Any]] else { continue }
                for item in items {
                    guard let itemObj = item["item"] as? [String: Any] else { continue }
                    if let tweet = parseTweetEntry(content: itemObj,
                                                   dateFormatter: dateFormatter),
                       tweet.id == tweetID {
                        return tweet
                    }
                }
            }
        }

        log("XProfileFetcher", "TweetDetail: focal tweet \(tweetID) not found in entries")
        return nil
    }

    /// Parses the focal tweet plus any consecutive same-author tweets that
    /// share its TimelineTimelineModule (self-thread). Single standalone
    /// tweets return one thread item; full self-threads return all of them
    /// in display order, each with its images and quoted-tweet URL.
    static func parseTweetDetailContent(
        data: Data, tweetID: String
    ) -> ParsedTweetContent? {
        guard let entries = tweetDetailEntries(from: data) else { return nil }
        let dateFormatter = makeXDateFormatter()

        for entry in entries {
            guard let content = entry["content"] as? [String: Any] else { continue }
            let entryType = content["entryType"] as? String

            if entryType == "TimelineTimelineItem" {
                if let item = parseTweetItem(content: content, dateFormatter: dateFormatter),
                   item.tweet.id == tweetID {
                    return ParsedTweetContent(
                        focal: item.tweet,
                        threadItems: [item.threadItem]
                    )
                }
            } else if entryType == "TimelineTimelineModule",
                      let items = content["items"] as? [[String: Any]] {
                let parsed: [ParsedTweetItem] = items.compactMap { item in
                    guard let itemObj = item["item"] as? [String: Any] else { return nil }
                    return parseTweetItem(content: itemObj, dateFormatter: dateFormatter)
                }
                guard let focalIdx = parsed.firstIndex(where: { $0.tweet.id == tweetID })
                else { continue }
                let focalAuthor = parsed[focalIdx].tweet.authorHandle
                let sameAuthor = parsed.filter { $0.tweet.authorHandle == focalAuthor }
                return ParsedTweetContent(
                    focal: parsed[focalIdx].tweet,
                    threadItems: sameAuthor.map(\.threadItem)
                )
            }
        }

        log("XProfileFetcher", "TweetDetail: focal tweet \(tweetID) not found in entries")
        return nil
    }

    /// Extracts the top reply from each `conversationthread-…` module that
    /// follows the focal tweet, up to `limit`. Skips the focal tweet itself
    /// and the trailing `tweetdetailrelatedtweets-…` related-posts module.
    static func parseTweetDetailReplies(
        data: Data, focalTweetID: String, limit: Int
    ) -> [ParsedReply] {
        guard limit > 0,
              let entries = tweetDetailEntries(from: data) else { return [] }
        let dateFormatter = makeXDateFormatter()

        var results: [ParsedReply] = []
        for entry in entries where results.count < limit {
            let entryID = entry["entryId"] as? String ?? ""
            guard entryID.hasPrefix("conversationthread-"),
                  let content = entry["content"] as? [String: Any],
                  (content["entryType"] as? String) == "TimelineTimelineModule",
                  let items = content["items"] as? [[String: Any]],
                  let firstItem = items.first?["item"] as? [String: Any],
                  let parsed = parseReplyEntry(
                    itemContent: firstItem, dateFormatter: dateFormatter
                  ),
                  parsed.id != focalTweetID else { continue }
            results.append(parsed)
        }
        return results
    }

    private static func tweetDetailEntries(from data: Data) -> [[String: Any]]? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let threadedConvo = dataObj["threaded_conversation_with_injections_v2"]
                  as? [String: Any],
              let instructions = threadedConvo["instructions"] as? [[String: Any]] else {
            log("XProfileFetcher", "Failed to parse TweetDetail JSON structure")
            return nil
        }
        guard let addEntries = instructions.first(
            where: { ($0["type"] as? String) == "TimelineAddEntries" }
        ), let entries = addEntries["entries"] as? [[String: Any]] else {
            log("XProfileFetcher", "No TimelineAddEntries in TweetDetail")
            return nil
        }
        return entries
    }

    private static func makeXDateFormatter() -> DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "EEE MMM dd HH:mm:ss Z yyyy"
        return dateFormatter
    }

    /// Pairs the existing `ParsedTweet` (used for header metadata) with the
    /// thread-item view of the same tweet (text/images/quote URL for body).
    private struct ParsedTweetItem {
        let tweet: ParsedTweet
        let threadItem: ParsedThreadItem
    }

    private static func parseTweetItem(
        content: [String: Any], dateFormatter: DateFormatter
    ) -> ParsedTweetItem? {
        guard let tweet = parseTweetEntry(content: content, dateFormatter: dateFormatter)
        else { return nil }

        let legacy = tweetLegacy(from: content)
        let bodyText = expandedDisplayText(legacy: legacy)

        let imageURLs: [String]
        if !tweet.carouselImageURLs.isEmpty {
            imageURLs = tweet.carouselImageURLs
        } else if let url = tweet.imageURL {
            imageURLs = [url]
        } else {
            imageURLs = []
        }

        let quotedURL = quotedTweetURL(legacy: legacy, content: content)

        return ParsedTweetItem(
            tweet: tweet,
            threadItem: ParsedThreadItem(
                id: tweet.id,
                text: bodyText,
                imageURLs: imageURLs,
                quotedTweetURL: quotedURL
            )
        )
    }

    /// Builds the body text shown in the article viewer for one thread item:
    /// 1) start from raw `full_text`, 2) strip leading thread @mentions via
    /// `display_text_range`, 3) expand t.co short URLs, 4) drop a trailing
    /// t.co (which is normally a quote-tweet/media link rendered separately).
    private static func expandedDisplayText(legacy: [String: Any]?) -> String {
        guard let legacy else { return "" }
        let fullText = legacy["full_text"] as? String ?? ""
        var text = XCommentText.stripLeadingMentions(
            fullText: fullText,
            displayTextRange: legacy["display_text_range"] as? [Int]
        )

        if let entities = legacy["entities"] as? [String: Any],
           let urlEntities = entities["urls"] as? [[String: Any]] {
            for urlEntity in urlEntities {
                guard let shortURL = urlEntity["url"] as? String,
                      let expandedURL = urlEntity["expanded_url"] as? String
                else { continue }
                text = text.replacingOccurrences(of: shortURL, with: expandedURL)
            }
        }

        return text.replacingOccurrences(
            of: "\\s*https://t\\.co/\\S+$",
            with: "",
            options: .regularExpression
        )
    }

    /// Reaches into the same `legacy` dict that `parseTweetEntry` reads,
    /// handling the `TweetWithVisibilityResults` wrapper.
    private static func tweetLegacy(from content: [String: Any]) -> [String: Any]? {
        guard let itemContent = content["itemContent"] as? [String: Any],
              let tweetResults = itemContent["tweet_results"] as? [String: Any],
              let tweetResult = tweetResults["result"] as? [String: Any] else { return nil }
        let actualResult: [String: Any]
        if (tweetResult["__typename"] as? String) == "TweetWithVisibilityResults",
           let tweet = tweetResult["tweet"] as? [String: Any] {
            actualResult = tweet
        } else {
            actualResult = tweetResult
        }
        return actualResult["legacy"] as? [String: Any]
    }

    /// Returns a canonical `https://x.com/{handle}/status/{id}` URL for the
    /// quoted tweet, falling back to `legacy.quoted_status_permalink.expanded`
    /// when the quoted user can't be resolved.
    private static func quotedTweetURL(
        legacy: [String: Any]?, content: [String: Any]
    ) -> String? {
        guard let legacy,
              (legacy["is_quote_status"] as? Bool) == true,
              let quotedID = legacy["quoted_status_id_str"] as? String else { return nil }

        if let itemContent = content["itemContent"] as? [String: Any],
           let tweetResults = itemContent["tweet_results"] as? [String: Any],
           let tweetResult = tweetResults["result"] as? [String: Any] {
            let result: [String: Any]
            if (tweetResult["__typename"] as? String) == "TweetWithVisibilityResults",
               let inner = tweetResult["tweet"] as? [String: Any] {
                result = inner
            } else {
                result = tweetResult
            }
            if let quoted = result["quoted_status_result"] as? [String: Any],
               let quotedResult = quoted["result"] as? [String: Any],
               let core = quotedResult["core"] as? [String: Any],
               let userResults = core["user_results"] as? [String: Any],
               let userResult = userResults["result"] as? [String: Any],
               let userCore = userResult["core"] as? [String: Any],
               let handle = userCore["screen_name"] as? String {
                return "https://x.com/\(handle)/status/\(quotedID)"
            }
        }

        if let permalink = legacy["quoted_status_permalink"] as? [String: Any],
           let expanded = permalink["expanded"] as? String, !expanded.isEmpty {
            return expanded.replacingOccurrences(
                of: "https://twitter.com/",
                with: "https://x.com/"
            )
        }
        return nil
    }

    private static func parseReplyEntry(
        itemContent: [String: Any], dateFormatter: DateFormatter
    ) -> ParsedReply? {
        guard let inner = itemContent["itemContent"] as? [String: Any],
              let tweetResults = inner["tweet_results"] as? [String: Any],
              let result = tweetResults["result"] as? [String: Any] else { return nil }

        let actualResult: [String: Any]
        if (result["__typename"] as? String) == "TweetWithVisibilityResults",
           let tweet = result["tweet"] as? [String: Any] {
            actualResult = tweet
        } else {
            actualResult = result
        }

        guard let legacy = actualResult["legacy"] as? [String: Any],
              let idStr = legacy["id_str"] as? String, !idStr.isEmpty else { return nil }

        if legacy["conversation_control"] != nil { return nil }

        let core = (actualResult["core"] as? [String: Any])?["user_results"] as? [String: Any]
        let userResult = core?["result"] as? [String: Any]
        let userCore = userResult?["core"] as? [String: Any]
        let authorName = userCore?["name"] as? String ?? ""
        let authorHandle = userCore?["screen_name"] as? String ?? ""

        let fullText = legacy["full_text"] as? String ?? ""
        let createdAt = legacy["created_at"] as? String ?? ""
        let trimmed = XCommentText.stripLeadingMentions(
            fullText: fullText,
            displayTextRange: legacy["display_text_range"] as? [Int]
        )

        return ParsedReply(
            id: idStr,
            text: trimmed,
            author: authorName,
            authorHandle: authorHandle,
            url: "https://x.com/\(authorHandle)/status/\(idStr)",
            publishedDate: dateFormatter.date(from: createdAt)
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
