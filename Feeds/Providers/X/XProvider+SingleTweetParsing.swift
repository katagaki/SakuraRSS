import Foundation

extension XProvider {

    // MARK: - TweetResultByRestId Response Parsing

    /// Parses a TweetResultByRestId response. Prefers note_tweet text for
    /// longform posts so the full body is returned instead of the truncated
    /// legacy.full_text.
    static func parseTweetResultByRestIdResponse(data: Data) -> ParsedTweet? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let tweetResult = dataObj["tweetResult"] as? [String: Any],
              let result = tweetResult["result"] as? [String: Any] else {
            log("XProvider", "Failed to parse TweetResultByRestId JSON structure")
            return nil
        }

        let actualResult: [String: Any]
        if (result["__typename"] as? String) == "TweetWithVisibilityResults",
           let tweet = result["tweet"] as? [String: Any] {
            actualResult = tweet
        } else {
            actualResult = result
        }

        return parseSingleTweet(from: actualResult, dateFormatter: makeXDateFormatter())
    }

    static func parseSingleTweet(
        from actualResult: [String: Any], dateFormatter: DateFormatter
    ) -> ParsedTweet? {
        guard let legacy = actualResult["legacy"] as? [String: Any] else { return nil }
        if legacy["retweeted_status_result"] != nil { return nil }

        let idStr = legacy["id_str"] as? String ?? ""
        guard !idStr.isEmpty else { return nil }
        let createdAt = legacy["created_at"] as? String ?? ""

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
        let cleanText = bestTweetText(legacy: legacy, actualResult: actualResult)

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

    /// Returns the longform note_tweet text when present, falling back to
    /// legacy.full_text. Expands t.co URLs and decodes HTML entities.
    static func bestTweetText(
        legacy: [String: Any], actualResult: [String: Any]
    ) -> String {
        if let noteTweet = actualResult["note_tweet"] as? [String: Any],
           let noteResults = noteTweet["note_tweet_results"] as? [String: Any],
           let noteResult = noteResults["result"] as? [String: Any],
           let noteText = noteResult["text"] as? String, !noteText.isEmpty {
            var text = noteText
            if let entitySet = noteResult["entity_set"] as? [String: Any],
               let urlEntities = entitySet["urls"] as? [[String: Any]] {
                text = expandTCoURLs(in: text, using: urlEntities)
            }
            return XProvider.decodeHTMLEntities(stripTrailingTCo(text))
        }

        var text = legacy["full_text"] as? String ?? ""
        if let entities = legacy["entities"] as? [String: Any],
           let urlEntities = entities["urls"] as? [[String: Any]] {
            text = expandTCoURLs(in: text, using: urlEntities)
        }
        return XProvider.decodeHTMLEntities(stripTrailingTCo(text))
    }

    static func expandTCoURLs(
        in text: String, using urlEntities: [[String: Any]]
    ) -> String {
        var result = text
        for urlEntity in urlEntities {
            guard let shortURL = urlEntity["url"] as? String,
                  let expandedURL = urlEntity["expanded_url"] as? String
            else { continue }
            result = result.replacingOccurrences(of: shortURL, with: expandedURL)
        }
        return result
    }

    static func stripTrailingTCo(_ text: String) -> String {
        text.replacingOccurrences(
            of: "\\s*https://t\\.co/\\S+$",
            with: "",
            options: .regularExpression
        )
    }
}
