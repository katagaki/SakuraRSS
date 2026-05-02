import Foundation

extension RedditCommentsFetcher {

    struct ParsedComment {
        let comment: FetchedComment
        let score: Int
    }

    /// Walks the svc HTML and pulls out every top-level (`depth="0"`)
    /// `<shreddit-comment>` element along with its body and score.
    static func parseTopLevelComments(
        html: String,
        subreddit: String,
        postID: String
    ) -> [ParsedComment] {
        guard let regex = try? NSRegularExpression(
            pattern: #"<shreddit-comment\b([^>]*)>"#,
            options: [.caseInsensitive]
        ) else { return [] }

        let nsHTML = html as NSString
        let matches = regex.matches(
            in: html, range: NSRange(location: 0, length: nsHTML.length)
        )

        var results: [ParsedComment] = []
        for match in matches where match.numberOfRanges >= 2 {
            let attrsRange = match.range(at: 1)
            let attrsString = nsHTML.substring(with: attrsRange)
            let attrs = parseAttributes(attrsString)
            guard attrs["depth"] == "0",
                  let thingID = attrs["thingid"],
                  !thingID.isEmpty else { continue }
            let body = extractBody(forThingID: thingID, in: html)
            guard !body.isEmpty else { continue }
            let author = attrs["author"] ?? ""
            let score = Int(attrs["score"] ?? "") ?? 0
            let createdDate = attrs["created"].flatMap(parseISO8601(_:))
            let permalink = attrs["permalink"]
            let sourceURL = permalink.flatMap {
                URL(string: "https://www.reddit.com\($0)")?.absoluteString
            }
            let fetched = FetchedComment(
                author: author,
                body: body,
                createdDate: createdDate,
                sourceURL: sourceURL
            )
            results.append(ParsedComment(comment: fetched, score: score))
        }
        return results
    }

    /// Reads attributes off a tag fragment like ` foo="bar" baz="qux"`. Keys
    /// are lowercased so callers can look them up without worrying about the
    /// camelCase variants Reddit emits (`thingId`, `postId`, etc.).
    static func parseAttributes(_ fragment: String) -> [String: String] {
        guard let regex = try? NSRegularExpression(
            pattern: #"([a-zA-Z][a-zA-Z0-9_-]*)\s*=\s*"([^"]*)""#
        ) else { return [:] }
        let nsFragment = fragment as NSString
        let matches = regex.matches(
            in: fragment, range: NSRange(location: 0, length: nsFragment.length)
        )
        var attrs: [String: String] = [:]
        for match in matches where match.numberOfRanges >= 3 {
            let key = nsFragment.substring(with: match.range(at: 1)).lowercased()
            let value = nsFragment.substring(with: match.range(at: 2))
            attrs[key] = value
        }
        return attrs
    }

    /// Pulls the markdown-rendered body out of the
    /// `<div id="<thingID>-post-rtjson-content">…</div>` block. The inner div
    /// only contains `<p>`/inline tags, so a lazy `</div>` match is safe.
    static func extractBody(forThingID thingID: String, in html: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: thingID)
        let pattern = "<div\\b[^>]*id=\"\(escaped)-post-rtjson-content\"[^>]*>([\\s\\S]*?)</div>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return ""
        }
        let nsHTML = html as NSString
        guard let match = regex.firstMatch(
            in: html, range: NSRange(location: 0, length: nsHTML.length)
        ), match.numberOfRanges >= 2 else {
            return ""
        }
        let raw = nsHTML.substring(with: match.range(at: 1))
        return RedditCommentText.clean(raw)
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601FormatterFallback: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Reddit emits microsecond precision (e.g. `2026-05-01T16:41:21.212000+0000`)
    /// which `ISO8601DateFormatter` rejects. Trim the fractional component to
    /// 3 digits before parsing.
    static func parseISO8601(_ value: String) -> Date? {
        let normalized = value.replacingOccurrences(
            of: #"\.(\d{1,3})\d*"#, with: ".$1", options: .regularExpression
        )
        return iso8601Formatter.date(from: normalized)
            ?? iso8601FormatterFallback.date(from: normalized)
    }
}
