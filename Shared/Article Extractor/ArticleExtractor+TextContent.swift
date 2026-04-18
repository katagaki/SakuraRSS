import Foundation
import SwiftSoup

extension ArticleExtractor {

    static let imgOpenPlaceholder = "{{SAKURA_IMG_OPEN}}"
    static let imgClosePlaceholder = "{{SAKURA_IMG_CLOSE}}"
    static let imgLinkOpenPlaceholder = "{{SAKURA_IMGLINK_OPEN}}"
    static let imgLinkClosePlaceholder = "{{SAKURA_IMGLINK_CLOSE}}"
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
    static let codeOpenPlaceholder = "{{SAKURA_CODE_OPEN}}"
    static let codeClosePlaceholder = "{{SAKURA_CODE_CLOSE}}"

    /// Extracts text from a block element, preserving `<br>` tags as newlines
    /// and `<a>` tags as Markdown links.
    static let doubleLFPlaceholder = "{{SAKURA_DOUBLE_LF}}"
    static let singleLFPlaceholder = "{{SAKURA_SINGLE_LF}}"

    static func textContent(of element: Element, baseURL: URL? = nil) throws -> String {
        promoteLazyImageSources(in: element)
        replaceImagesInDOM(in: element, baseURL: baseURL)
        var html = try element.html()
        // Strip <svg>…</svg> entirely — icon SVGs inside anchors (share
        // buttons, nav arrows) leave anchors with no meaningful text, and
        // the link-replacement regex would otherwise capture the SVG markup
        // as "link text" and serialize the href itself as visible text.
        html = html.replacingOccurrences(
            of: "<svg\\b[^>]*>[\\s\\S]*?</svg>",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        // Consecutive <br> tags indicate a paragraph break in poorly-structured HTML.
        html = html.replacingOccurrences(
            of: "<br\\s*/?>(\\s*<br\\s*/?>)+",
            with: doubleLFPlaceholder,
            options: .regularExpression
        )
        html = html.replacingOccurrences(
            of: "<br\\s*/?>",
            with: singleLFPlaceholder,
            options: .regularExpression
        )
        // Preserve literal newlines in the HTML source (e.g. Markdown content
        // that has no <br> or <p> tags) before SwiftSoup's .text() strips them.
        html = html.replacingOccurrences(of: "\n\n", with: doubleLFPlaceholder)
        html = html.replacingOccurrences(of: "\n", with: singleLFPlaceholder)
        html = replaceLinkedImgTags(in: html, baseURL: baseURL)
        html = replaceImgTags(in: html, baseURL: baseURL)
        html = replaceLinkTags(in: html)
        html = replaceFormattingTags(in: html)
        let fragment = try SwiftSoup.parseBodyFragment(html)
        var text = try fragment.body()?.text() ?? ""
        text = text.replacingOccurrences(of: doubleLFPlaceholder, with: "\n\n")
        text = text.replacingOccurrences(of: singleLFPlaceholder, with: "\n")
        text = escapeBracketsInLinkText(text,
                                        open: linkOpenPlaceholder,
                                        mid: linkMidPlaceholder)
        // Escape literal markers before SAKURA placeholders become real ones.
        text = ArticleMarker.escape(text)
        text = convertPlaceholdersToMarkdown(text)
        text = stripInvalidURLSupSub(text)
        text = stripRemainingHTMLTags(text)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Rewrites lazy-loaded `<img>` and `<amp-img>` tags so their `src`
    /// attribute holds the best available URL.  Lets the regex-based
    /// `replaceImgTags` keep working for sites using `data-src` / `srcset`.
    static func promoteLazyImageSources(in element: Element) {
        guard let images = try? element.select("img, amp-img") else { return }
        for image in images {
            let currentSrc = (try? image.attr("src")) ?? ""
            let currentValid = !currentSrc.isEmpty
                && !currentSrc.hasPrefix("data:")
                && isLikelyContentImage(currentSrc)
            if currentValid { continue }
            guard let best = bestImageURL(from: image), !best.isEmpty else {
                continue
            }
            _ = try? image.attr("src", best)
        }
    }

    /// Replaces `<img>` / `<amp-img>` / `<picture>` elements with text-only
    /// placeholders directly in the DOM.  Avoids regex fragility on malformed
    /// markup, nested tags, and attributes with escaped quotes.  Preserves
    /// wrapping `<a href>` by emitting an `{{IMGLINK}}` suffix.
    static func replaceImagesInDOM(in element: Element, baseURL: URL?) {
        guard let images = try? element.select("img, amp-img, picture") else {
            return
        }
        for image in images {
            guard image.parent() != nil else { continue }
            guard let rawSrc = bestImageURL(from: image), !rawSrc.isEmpty,
                  isLikelyContentImage(rawSrc),
                  let resolved = resolveURL(rawSrc, against: baseURL) else {
                _ = try? image.remove()
                continue
            }
            var target: Element = image
            var linkSuffix = ""
            if let parent = image.parent(),
               parent.tagName().lowercased() == "a",
               parent.children().size() == 1,
               let href = try? parent.attr("href"),
               !href.isEmpty,
               let resolvedHref = resolveURL(href, against: baseURL) {
                linkSuffix = "\(imgLinkOpenPlaceholder)\(resolvedHref)\(imgLinkClosePlaceholder)"
                target = parent
            }
            let placeholder = "\(imgOpenPlaceholder)\(resolved)\(linkSuffix)\(imgClosePlaceholder)"
            do {
                try target.before(placeholder)
                try target.remove()
            } catch {
                _ = try? target.remove()
            }
        }
    }

    // MARK: - HTML Tag Replacement

    /// Handles `<a href="..."><img src="..."></a>` patterns, converting them to
    /// image placeholders with link info before the separate img/link replacements run.
    private static func replaceLinkedImgTags(in html: String, baseURL: URL? = nil) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: "<a\\s[^>]*href=[\"']([^\"']+)[\"'][^>]*>\\s*<img\\s[^>]*src=[\"']([^\"']+)[\"'][^>]*/?>\\s*</a>",
            options: .caseInsensitive
        ) else { return html }
        var result = html
        let nsHTML = result as NSString
        let matches = regex.matches(in: result, range: NSRange(location: 0, length: nsHTML.length))
        for match in matches.reversed() {
            let linkURL = nsHTML.substring(with: match.range(at: 1))
            let imgURL = nsHTML.substring(with: match.range(at: 2))
            if isLikelyContentImage(imgURL),
               let resolvedImg = resolveURL(imgURL, against: baseURL) {
                let resolvedLink = resolveURL(linkURL, against: baseURL) ?? linkURL
                let replacement = "\(imgOpenPlaceholder)\(resolvedImg)\(imgLinkOpenPlaceholder)\(resolvedLink)\(imgLinkClosePlaceholder)\(imgClosePlaceholder)"
                result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
            }
        }
        return result
    }

    private static func replaceImgTags(in html: String, baseURL: URL? = nil) -> String {
        guard let imgRegex = try? NSRegularExpression(
            pattern: "<img\\s[^>]*src=[\"']([^\"']+)[\"'][^>]*/?>",
            options: .caseInsensitive
        ) else { return html }
        var result = html
        let nsHTML = result as NSString
        let imgMatches = imgRegex.matches(in: result, range: NSRange(location: 0, length: nsHTML.length))
        for match in imgMatches.reversed() {
            let imgURL = nsHTML.substring(with: match.range(at: 1))
            if isLikelyContentImage(imgURL), let resolved = resolveURL(imgURL, against: baseURL) {
                #if DEBUG
                debugPrint("[Image] Inline <img> extracted: \(resolved)")
                #endif
                let replacement = "\(imgOpenPlaceholder)\(resolved)\(imgClosePlaceholder)"
                result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
            } else {
                #if DEBUG
                debugPrint("[Image] Inline <img> skipped: \(imgURL)")
                #endif
                result = (result as NSString).replacingCharacters(in: match.range, with: "")
            }
        }
        return result
    }

    private static func replaceLinkTags(in html: String) -> String {
        var result = html

        // Remove empty links first.
        result = result.replacingOccurrences(
            of: "<a\\s[^>]*>\\s*</a>",
            with: "",
            options: .regularExpression
        )

        // Replace links using NSRegularExpression so we can collapse newline
        // placeholders inside the captured link text.  A simple
        // `replacingOccurrences(of:with:options:.regularExpression)` substitution
        // would preserve the placeholders verbatim, producing broken Markdown
        // like `[\nDJIA\n46504.67\n](\url)`.
        guard let regex = try? NSRegularExpression(
            pattern: "<a\\s[^>]*href=[\"']([^\"']+)[\"'][^>]*>(.+?)</a>",
            options: .caseInsensitive
        ) else { return result }

        let nsResult = result as NSString
        let matches = regex.matches(in: result,
                                    range: NSRange(location: 0, length: nsResult.length))
        for match in matches.reversed() {
            let href = nsResult.substring(with: match.range(at: 1))
            var linkText = nsResult.substring(with: match.range(at: 2))
            // Collapse newline placeholders inside link text to a single space.
            linkText = linkText
                .replacingOccurrences(of: doubleLFPlaceholder, with: " ")
                .replacingOccurrences(of: singleLFPlaceholder, with: " ")
            // Drop links whose visible text is empty or just the href itself —
            // typically icon-only share buttons that leave nothing to render.
            let visibleText = linkText
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if visibleText.isEmpty || visibleText == href {
                result = (result as NSString).replacingCharacters(in: match.range, with: "")
                continue
            }
            let replacement = "\(linkOpenPlaceholder)\(linkText)\(linkMidPlaceholder)\(href)\(linkClosePlaceholder)"
            result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
        }
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
        result = result.replacingOccurrences(
            of: "<code(?:\\s[^>]*)?>", with: codeOpenPlaceholder,
            options: [.regularExpression, .caseInsensitive]
        )
        result = result.replacingOccurrences(
            of: "</code>", with: codeClosePlaceholder, options: .caseInsensitive
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
        result = result.replacingOccurrences(of: imgLinkOpenPlaceholder, with: "{{IMGLINK}}")
        result = result.replacingOccurrences(of: imgLinkClosePlaceholder, with: "{{/IMGLINK}}")
        result = result.replacingOccurrences(of: codeOpenPlaceholder, with: "`")
        result = result.replacingOccurrences(of: codeClosePlaceholder, with: "`")
        return result
    }

    // MARK: - Utility

    static func isLikelyContentImage(_ url: String) -> Bool {
        // Skip data URIs (inline SVG placeholders, base64 spacers, etc.)
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
                // Footnote anchors use fragment-only URLs like "#fn1" — let them through.
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

    /// Collapses runs of empty, formatting-only, or separator-only lines so
    /// cleaned article text doesn't render with gaping vertical gaps.
    /// Runs after paragraph collection so inter-paragraph blank lines survive.
    static func compactWhitespace(in text: String) -> String {
        var result = text
        // Drop Markdown horizontal rules that are alone on a line.  They
        // almost always come from navigation separators or ad blocks.
        result = result.replacingOccurrences(
            of: #"(?m)^[ \t]*(?:-{3,}|={3,}|_{3,}|\*{3,})[ \t]*$"#,
            with: "",
            options: .regularExpression
        )
        // Lines that contain only `|`, punctuation, or bullet-like glyphs
        // (e.g. breadcrumb "› › ›" residue) are noise.
        result = result.replacingOccurrences(
            of: #"(?m)^[ \t]*[\|\·•‣▪▫◦▶›»→・、,]+[ \t]*$"#,
            with: "",
            options: .regularExpression
        )
        // Lines with only bold/italic markers and no real content
        // (e.g. `**  **` or `* *`) — typically empty share buttons.
        result = result.replacingOccurrences(
            of: #"(?m)^[ \t]*(?:\*{1,3}|_{1,3})[ \t]*(?:\*{1,3}|_{1,3})?[ \t]*$"#,
            with: "",
            options: .regularExpression
        )
        // Collapse runs of 3+ newlines back to a paragraph break.
        result = result.replacingOccurrences(
            of: "\\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
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
