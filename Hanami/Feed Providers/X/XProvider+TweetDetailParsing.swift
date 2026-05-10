import Foundation

public extension XProvider {

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

        log("XProvider", "TweetDetail: focal tweet \(tweetID) not found in entries")
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

        log("XProvider", "TweetDetail: focal tweet \(tweetID) not found in entries")
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

    static func tweetDetailEntries(from data: Data) -> [[String: Any]]? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let threadedConvo = dataObj["threaded_conversation_with_injections_v2"]
                  as? [String: Any],
              let instructions = threadedConvo["instructions"] as? [[String: Any]] else {
            log("XProvider", "Failed to parse TweetDetail JSON structure")
            return nil
        }
        guard let addEntries = instructions.first(
            where: { ($0["type"] as? String) == "TimelineAddEntries" }
        ), let entries = addEntries["entries"] as? [[String: Any]] else {
            log("XProvider", "No TimelineAddEntries in TweetDetail")
            return nil
        }
        return entries
    }

    static func makeXDateFormatter() -> DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "EEE MMM dd HH:mm:ss Z yyyy"
        return dateFormatter
    }

    /// Pairs the existing `ParsedTweet` (used for header metadata) with the
    /// thread-item view of the same tweet (text/images/quote URL for body).
    struct ParsedTweetItem {
        public let tweet: ParsedTweet
        public let threadItem: ParsedThreadItem
    }

    static func parseTweetItem(
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
    static func expandedDisplayText(legacy: [String: Any]?) -> String {
        guard let legacy else { return "" }
        let fullText = legacy["full_text"] as? String ?? ""
        var text = XProvider.stripLeadingMentions(
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
    static func tweetLegacy(from content: [String: Any]) -> [String: Any]? {
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
    static func quotedTweetURL(
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

    static func parseReplyEntry(
        itemContent: [String: Any], dateFormatter: DateFormatter
    ) -> ParsedReply? {
        guard let inner = itemContent["itemContent"] as? [String: Any],
              inner["promotedMetadata"] == nil,
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

        let core = (actualResult["core"] as? [String: Any])?["user_results"] as? [String: Any]
        let userResult = core?["result"] as? [String: Any]
        let userCore = userResult?["core"] as? [String: Any]
        let authorName = userCore?["name"] as? String ?? ""
        let authorHandle = userCore?["screen_name"] as? String ?? ""

        let fullText = legacy["full_text"] as? String ?? ""
        let createdAt = legacy["created_at"] as? String ?? ""
        let trimmed = XProvider.stripLeadingMentions(
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
}
