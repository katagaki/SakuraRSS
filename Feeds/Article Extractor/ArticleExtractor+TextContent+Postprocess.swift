import Foundation

extension ArticleExtractor {

    // MARK: - Placeholder Conversion

    static func convertPlaceholdersToMarkdown(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: linkOpenPlaceholder, with: "[")
        result = result.replacingOccurrences(of: linkMidPlaceholder, with: "](")
        result = result.replacingOccurrences(of: linkClosePlaceholder, with: ")")
        result = result.replacingOccurrences(of: boldOpenPlaceholder, with: "**")
        result = result.replacingOccurrences(of: boldClosePlaceholder, with: "**")
        result = result.replacingOccurrences(of: italicOpenPlaceholder, with: "*")
        result = result.replacingOccurrences(of: italicClosePlaceholder, with: "*")
        result = result.replacingOccurrences(of: supOpenPlaceholder, with: "{{SUP}}")
        result = result.replacingOccurrences(of: supClosePlaceholder, with: "{{/SUP}}")
        result = result.replacingOccurrences(of: subOpenPlaceholder, with: "{{SUB}}")
        result = result.replacingOccurrences(of: subClosePlaceholder, with: "{{/SUB}}")
        result = result.replacingOccurrences(of: imgOpenPlaceholder, with: "{{IMG}}")
        result = result.replacingOccurrences(of: imgClosePlaceholder, with: "{{/IMG}}")
        result = result.replacingOccurrences(of: imgLinkOpenPlaceholder, with: "{{IMGLINK}}")
        result = result.replacingOccurrences(of: imgLinkClosePlaceholder, with: "{{/IMGLINK}}")
        result = result.replacingOccurrences(of: codeOpenPlaceholder, with: "`")
        result = result.replacingOccurrences(of: codeClosePlaceholder, with: "`")
        return result
    }

    // MARK: - Utility

    static func isLikelyContentImage(_ url: String) -> Bool {
        if url.hasPrefix("data:") {
            return false
        }
        let lowered = url.lowercased()
        let skipPatterns = [
            "gravatar.com", "pixel", "spacer", "blank",
            "1x1", "transparent", "tracking", "beacon",
            ".gif", ".svg", "feeds.feedburner.com", "badge",
            "icon", "emoji", "smiley", "avatar",
            "ad.", "ads.", "doubleclick", "googlesyndication"
        ]
        for pattern in skipPatterns where lowered.contains(pattern) {
            return false
        }
        return true
    }

    /// Removes sup/sub markers whose content contains an invalid URL.
    static func stripInvalidURLSupSub(_ text: String) -> String {
        let pattern = #"\{\{(SUP|SUB)\}\}(.+?)\{\{/(SUP|SUB)\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        var result = text
        let nsText = result as NSString
        let matches = regex.matches(in: result, range: NSRange(location: 0, length: nsText.length))
        for match in matches.reversed() {
            let content = nsText.substring(with: match.range(at: 2))
            let linkPattern = #"\[([^\]]+)\]\(([^)]+)\)"#
            if let linkRegex = try? NSRegularExpression(pattern: linkPattern),
               let linkMatch = linkRegex.firstMatch(
                in: content, range: NSRange(location: 0, length: (content as NSString).length)
               ) {
                let urlString = (content as NSString).substring(with: linkMatch.range(at: 2))
                // Footnote anchors use fragment-only URLs like "#fn1"; keep them.
                if urlString.hasPrefix("#") { continue }
                if URL(string: urlString) == nil {
                    result = (result as NSString).replacingCharacters(in: match.range, with: "")
                }
            } else if content.hasPrefix("http://") || content.hasPrefix("https://")
                        || content.hasPrefix("//") {
                if URL(string: content) == nil {
                    result = (result as NSString).replacingCharacters(in: match.range, with: "")
                }
            }
        }
        return result
    }

    /// Escapes `[` and `]` characters that appear inside link text.
    static func escapeBracketsInLinkText(
        _ text: String,
        open: String,
        mid: String
    ) -> String {
        var result = ""
        var remaining = text[text.startIndex...]
        while let openRange = remaining.range(of: open) {
            result += remaining[remaining.startIndex..<openRange.lowerBound]
            result += open
            let afterOpen = remaining[openRange.upperBound...]
            if let midRange = afterOpen.range(of: mid) {
                let linkText = afterOpen[afterOpen.startIndex..<midRange.lowerBound]
                result += linkText
                    .replacingOccurrences(of: "[", with: "\\[")
                    .replacingOccurrences(of: "]", with: "\\]")
                result += mid
                remaining = afterOpen[midRange.upperBound...]
            } else {
                remaining = afterOpen
            }
        }
        result += remaining
        return result
    }

    /// Collapses empty, formatting-only, or separator-only lines in extracted text.
    static func compactWhitespace(in text: String) -> String {
        var result = text
        result = result.replacingOccurrences(
            of: #"(?m)^[ \t]*(?:-{3,}|={3,}|_{3,}|\*{3,})[ \t]*$"#,
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"(?m)^[ \t]*[\|\·•‣▪▫◦▶›»→・、,]+[ \t]*$"#,
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"(?m)^[ \t]*(?:\*{1,3}|_{1,3})[ \t]*(?:\*{1,3}|_{1,3})?[ \t]*$"#,
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "\\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Link texts used by partial-feed CTAs at the end of an item
    /// (Ars Technica's "Read full article" / "Comments" pair, etc.).
    /// Compared case-insensitively against the trimmed Markdown link text.
    private static let trailingFeedCTATexts: Set<String> = [
        "read full article",
        "read full story",
        "read the full article",
        "read the full story",
        "read the rest",
        "read the rest of this entry",
        "read the rest of this entry »",
        "read more",
        "read more...",
        "read more…",
        "read more »",
        "continue reading",
        "continue reading...",
        "continue reading…",
        "continue reading »",
        "view original",
        "view full article",
        "view on website",
        "view article",
        "see full article",
        "see more",
        "comments",
        "view comments",
        "view all comments",
        "leave a comment",
        "0 comments",
        "discuss on hacker news"
    ]

    /// Strips trailing paragraphs whose entire content is a single Markdown
    /// link with text matching `trailingFeedCTATexts`. Targets boilerplate
    /// like Ars Technica's "Read full article" / "Comments" footer that
    /// shows up in partial-feed RSS items.
    static func removeTrailingFeedCTAParagraphs(_ paragraphs: [String]) -> [String] {
        var result = paragraphs
        while let last = result.last, isFeedCTAParagraph(last) {
            result.removeLast()
        }
        return result
    }

    /// Detects whether feed-supplied HTML carries a "Read full article" /
    /// "Comments" style anchor near its end, indicating the snippet is a
    /// partial preview rather than the full article body. Used by the
    /// automatic extraction cascade to skip the feed-content fallback and
    /// fetch the canonical URL instead.
    static func looksLikePartialFeedSnippet(_ html: String) -> Bool {
        let tail = String(html.suffix(4000))
        let pattern = #"<a\b[^>]*>([\s\S]+?)</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        else { return false }
        let nsTail = tail as NSString
        let matches = regex.matches(
            in: tail, range: NSRange(location: 0, length: nsTail.length)
        )
        for match in matches {
            let inner = nsTail.substring(with: match.range(at: 1))
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            if trailingFeedCTATexts.contains(inner) {
                return true
            }
        }
        return false
    }

    private static func isFeedCTAParagraph(_ paragraph: String) -> Bool {
        let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let pattern = #"^\[((?:[^\]\\]|\\.)+)\]\([^)\s]+\)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let nsTrimmed = trimmed as NSString
        guard let match = regex.firstMatch(
            in: trimmed,
            range: NSRange(location: 0, length: nsTrimmed.length)
        ), match.numberOfRanges >= 2 else {
            return false
        }
        let linkText = nsTrimmed.substring(with: match.range(at: 1))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return trailingFeedCTATexts.contains(linkText)
    }

    /// Strips any remaining HTML tags that may have leaked through parsing.
    static func stripRemainingHTMLTags(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&apos;", with: "'")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        result = result.replacingOccurrences(
            of: "[ \\t]+",
            with: " ",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "\\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
