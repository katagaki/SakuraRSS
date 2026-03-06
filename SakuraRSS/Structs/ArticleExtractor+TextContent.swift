import Foundation
import SwiftSoup

extension ArticleExtractor {

    static let imgOpenPlaceholder = "{{SAKURA_IMG_OPEN}}"
    static let imgClosePlaceholder = "{{SAKURA_IMG_CLOSE}}"
    static let brPlaceholder = "{{SAKURA_BR}}"
    static let linkOpenPlaceholder = "{{SAKURA_LINK_OPEN}}"
    static let linkMidPlaceholder = "{{SAKURA_LINK_MID}}"
    static let linkClosePlaceholder = "{{SAKURA_LINK_CLOSE}}"
    static let boldOpenPlaceholder = "{{SAKURA_BOLD_OPEN}}"
    static let boldClosePlaceholder = "{{SAKURA_BOLD_CLOSE}}"
    static let italicOpenPlaceholder = "{{SAKURA_ITALIC_OPEN}}"
    static let italicClosePlaceholder = "{{SAKURA_ITALIC_CLOSE}}"
    static let supOpenPlaceholder = "{{SAKURA_SUP_OPEN}}"
    static let supClosePlaceholder = "{{SAKURA_SUP_CLOSE}}"
    static let subOpenPlaceholder = "{{SAKURA_SUB_OPEN}}"
    static let subClosePlaceholder = "{{SAKURA_SUB_CLOSE}}"

    /// Extracts text from a block element, preserving `<br>` tags as newlines
    /// and `<a>` tags as Markdown links.
    static func textContent(of element: Element) throws -> String {
        var html = try element.html()
        html = html.replacingOccurrences(
            of: "<br\\s*/?>",
            with: brPlaceholder,
            options: .regularExpression
        )
        html = replaceImgTags(in: html)
        html = replaceLinkTags(in: html)
        html = replaceFormattingTags(in: html)
        let fragment = try SwiftSoup.parseBodyFragment(html)
        var text = try fragment.body()?.text() ?? ""
        text = text.replacingOccurrences(of: brPlaceholder, with: "\n")
        text = escapeBracketsInLinkText(text,
                                        open: linkOpenPlaceholder,
                                        mid: linkMidPlaceholder)
        text = convertPlaceholdersToMarkdown(text)
        text = stripInvalidURLSupSub(text)
        text = stripRemainingHTMLTags(text)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - HTML Tag Replacement

    private static func replaceImgTags(in html: String) -> String {
        guard let imgRegex = try? NSRegularExpression(
            pattern: "<img\\s[^>]*src=[\"']([^\"']+)[\"'][^>]*/?>",
            options: .caseInsensitive
        ) else { return html }
        var result = html
        let nsHTML = result as NSString
        let imgMatches = imgRegex.matches(in: result, range: NSRange(location: 0, length: nsHTML.length))
        for match in imgMatches.reversed() {
            let imgURL = nsHTML.substring(with: match.range(at: 1))
            if isLikelyContentImage(imgURL) {
                let replacement = "\(imgOpenPlaceholder)\(imgURL)\(imgClosePlaceholder)"
                result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
            } else {
                result = (result as NSString).replacingCharacters(in: match.range, with: "")
            }
        }
        return result
    }

    private static func replaceLinkTags(in html: String) -> String {
        var result = html
        result = result.replacingOccurrences(
            of: "<a\\s[^>]*href=[\"']([^\"']+)[\"'][^>]*>(.+?)</a>",
            with: "\(linkOpenPlaceholder)$2\(linkMidPlaceholder)$1\(linkClosePlaceholder)",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "<a\\s[^>]*>\\s*</a>",
            with: "",
            options: .regularExpression
        )
        return result
    }

    private static func replaceFormattingTags(in html: String) -> String {
        var result = html
        for tag in ["strong", "b"] {
            result = result.replacingOccurrences(
                of: "<\(tag)(?:\\s[^>]*)?>", with: boldOpenPlaceholder,
                options: [.regularExpression, .caseInsensitive]
            )
            result = result.replacingOccurrences(
                of: "</\(tag)>", with: boldClosePlaceholder, options: .caseInsensitive
            )
        }
        result = result.replacingOccurrences(
            of: "<em(?:\\s[^>]*)?>", with: italicOpenPlaceholder,
            options: [.regularExpression, .caseInsensitive]
        )
        result = result.replacingOccurrences(
            of: "</em>", with: italicClosePlaceholder, options: .caseInsensitive
        )
        result = result.replacingOccurrences(
            of: #"<i(?:\s[^>]*)?>"#, with: italicOpenPlaceholder,
            options: [.regularExpression, .caseInsensitive]
        )
        result = result.replacingOccurrences(
            of: "</i>", with: italicClosePlaceholder, options: .caseInsensitive
        )
        result = result.replacingOccurrences(
            of: "<sup(?:\\s[^>]*)?>", with: supOpenPlaceholder,
            options: [.regularExpression, .caseInsensitive]
        )
        result = result.replacingOccurrences(
            of: "</sup>", with: supClosePlaceholder, options: .caseInsensitive
        )
        result = result.replacingOccurrences(
            of: "<sub(?:\\s[^>]*)?>", with: subOpenPlaceholder,
            options: [.regularExpression, .caseInsensitive]
        )
        result = result.replacingOccurrences(
            of: "</sub>", with: subClosePlaceholder, options: .caseInsensitive
        )
        return result
    }

    // MARK: - Placeholder Conversion

    private static func convertPlaceholdersToMarkdown(_ text: String) -> String {
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
        return result
    }

    // MARK: - Utility

    static func isLikelyContentImage(_ url: String) -> Bool {
        let lowered = url.lowercased()
        let skipPatterns = [
            "gravatar.com", "pixel", "spacer", "blank",
            "1x1", "transparent", "tracking", "beacon",
            ".gif", "feeds.feedburner.com", "badge",
            "icon", "emoji", "smiley", "avatar",
            "ad.", "ads.", "doubleclick", "googlesyndication"
        ]
        for pattern in skipPatterns {
            if lowered.contains(pattern) { return false } // swiftlint:disable:this for_where
        }
        return true
    }

    /// Removes `{{SUP}}…{{/SUP}}` and `{{SUB}}…{{/SUB}}` markers whose
    /// content contains an invalid URL (either as a Markdown link or raw URL).
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
