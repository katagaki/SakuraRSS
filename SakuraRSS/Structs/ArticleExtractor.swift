import Foundation
import SwiftSoup

struct ArticleExtractor {

    private static let contentSelectors = [
        "article",
        "[role=main]",
        "main",
        ".post-content",
        ".entry-content",
        ".article-body",
        ".article-content",
        ".post-body",
        ".story-body",
        ".content-body",
        "#article-body",
        "#content",
        ".post",
        ".entry"
    ]

    private static let noiseSelectors = [
        "nav",
        "header",
        "footer",
        "aside",
        ".sidebar",
        ".navigation",
        ".nav",
        ".navbar",
        ".menu",
        ".main-menu",
        ".site-menu",
        ".mobile-menu",
        ".dropdown-menu",
        ".breadcrumb",
        ".breadcrumbs",
        ".social-share",
        ".share-buttons",
        ".sharing",
        ".related-posts",
        ".related-articles",
        ".comments",
        ".comment-section",
        ".advertisement",
        ".ad-container",
        ".ad",
        ".ads",
        ".cookie-banner",
        ".cookie-notice",
        ".popup",
        ".modal",
        ".newsletter",
        ".subscribe",
        ".signup",
        ".toolbar",
        ".pagination",
        ".pager",
        ".tags",
        ".tag-list",
        "[role=navigation]",
        "[role=banner]",
        "[role=complementary]",
        "[role=contentinfo]",
        "[aria-label*=menu]",
        "[aria-label*=Menu]",
        "[aria-label*=navigation]",
        "[aria-label*=Navigation]",
        "script",
        "style",
        "noscript",
        "iframe",
        "form",
        "button",
        "select",
        "input",
        "svg",
        "canvas"
    ]

    private static let blockElements = [
        "p", "h1", "h2", "h3", "h4", "h5", "h6",
        "blockquote", "li", "figcaption", "pre", "td", "th"
    ]

    static func extractText(fromHTML html: String,
                             excludeTitle: String? = nil,
                             excludeImageURL: String? = nil) -> String? {
        guard !html.isEmpty else { return nil }
        do {
            let doc = try SwiftSoup.parse(html)
            removeNoise(from: doc)
            let element = try findMainContent(from: doc)
            // Remove any remaining noise inside content area
            removeNoise(from: element)
            let paragraphs = try extractParagraphs(from: element,
                                                   excludeTitle: excludeTitle,
                                                   excludeImageURL: excludeImageURL)
            let result = paragraphs.joined(separator: "\n\n")
            let cleaned = stripRemainingHTMLTags(result)
            return cleaned.isEmpty ? nil : cleaned
        } catch {
            return nil
        }
    }

    static func extractText(fromURL url: URL,
                             excludeTitle: String? = nil,
                             excludeImageURL: String? = nil) async -> String? {
        if WebViewExtractor.requiresWebView(for: url) {
            #if DEBUG
            debugPrint("Extracting text using WebView from \(url)")
            #endif
            let extractor = WebViewExtractor()
            if let text = await extractor.extractText(from: url) {
                return text
            }
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else {
                return nil
            }
            return extractText(fromHTML: html, excludeTitle: excludeTitle,
                               excludeImageURL: excludeImageURL)
        } catch {
            return nil
        }
    }

    // MARK: - Private Helpers

    private static func removeNoise(from element: Element) {
        for selector in noiseSelectors {
            do {
                let elements = try element.select(selector)
                try elements.remove()
            } catch {
                continue
            }
        }

        // Remove elements that look like menus (lists of links with little text)
        do {
            let lists = try element.select("ul, ol")
            for list in lists {
                let links = try list.select("a")
                let items = try list.select("li")
                // If most list items are just links, it's likely a menu
                if items.size() > 2 && links.size() >= items.size() {
                    let totalText = try list.text()
                    let avgTextPerItem = totalText.count / max(items.size(), 1)
                    if avgTextPerItem < 50 {
                        try list.remove()
                    }
                }
            }
        } catch {
            // Menu detection is best-effort; failures are non-critical
        }
    }

    private static func findMainContent(from doc: Document) throws -> Element {
        for selector in contentSelectors {
            let elements = try doc.select(selector)
            if let element = elements.first() {
                let text = try element.text()
                if text.count > 100 {
                    return element
                }
            }
        }
        return doc.body() ?? doc
    }

    private static func extractParagraphs(from element: Element,
                                          excludeTitle: String? = nil,
                                          excludeImageURL: String? = nil) throws -> [String] {
        var paragraphs: [String] = []
        try collectBlocks(from: element, into: &paragraphs,
                          excludeTitle: excludeTitle, excludeImageURL: excludeImageURL)

        if paragraphs.isEmpty {
            let text = try textContent(of: element)
            return text.isEmpty ? [] : [text]
        }

        return paragraphs
    }

    /// Walks the DOM tree collecting text from block-level elements.
    /// Recurses into non-block wrappers (div, section, etc.) so that
    /// nested blocks like `<div><p>…</p></div>` don't produce duplicates.
    /// Treats leaf divs (divs with no block-level children) as paragraphs.
    private static func collectBlocks(from element: Element, into paragraphs: inout [String],
                                      excludeTitle: String? = nil,
                                      excludeImageURL: String? = nil) throws {
        for child in element.children() {
            let tag = child.tagName().lowercased()
            if tag == "img" {
                if let src = try? child.attr("src"), !src.isEmpty, isLikelyContentImage(src),
                   src != excludeImageURL {
                    paragraphs.append("{{IMG}}\(src){{/IMG}}")
                }
            } else if tag == "picture" {
                // Extract the <img> inside <picture>, ignoring <source> elements
                if let img = try? child.select("img").first(),
                   let src = try? img.attr("src"), !src.isEmpty, isLikelyContentImage(src),
                   src != excludeImageURL {
                    paragraphs.append("{{IMG}}\(src){{/IMG}}")
                }
            } else if tag == "figure" {
                // Extract image from figure, then caption
                if let img = try? child.select("img").first(),
                   let src = try? img.attr("src"), !src.isEmpty, isLikelyContentImage(src),
                   src != excludeImageURL {
                    paragraphs.append("{{IMG}}\(src){{/IMG}}")
                }
                if let caption = try? child.select("figcaption").first() {
                    let captionText = try textContent(of: caption)
                    if !captionText.isEmpty {
                        paragraphs.append("*\(captionText)*")
                    }
                }
            } else if blockElements.contains(tag) || isLeafBlock(child) {
                var text = try textContent(of: child)
                if !text.isEmpty {
                    let headingTags = ["h1", "h2", "h3", "h4", "h5", "h6"]
                    if headingTags.contains(tag),
                       let excludeTitle,
                       text.caseInsensitiveCompare(excludeTitle) == .orderedSame {
                        // Skip headers that match the feed title
                    } else {
                        switch tag {
                        case "h1": text = "# \(text)"
                        case "h2": text = "## \(text)"
                        case "h3": text = "### \(text)"
                        case "h4", "h5", "h6": text = "**\(text)**"
                        default: break
                        }
                        paragraphs.append(text)
                    }
                }
            } else {
                try collectBlocks(from: child, into: &paragraphs,
                                  excludeTitle: excludeTitle, excludeImageURL: excludeImageURL)
            }
        }
    }

    /// A wrapper element (div, section, span, etc.) that contains no nested
    /// block-level or structural children should be treated as a leaf paragraph.
    private static func isLeafBlock(_ element: Element) -> Bool {
        let structuralTags: Set<String> = ["div", "section", "article", "main", "aside"]
        for child in element.children() {
            let tag = child.tagName().lowercased()
            if blockElements.contains(tag) || structuralTags.contains(tag) {
                return false
            }
        }
        let text = (try? element.text()) ?? ""
        return !text.isEmpty
    }

    private static let imgOpenPlaceholder = "{{SAKURA_IMG_OPEN}}"
    private static let imgClosePlaceholder = "{{SAKURA_IMG_CLOSE}}"
    private static let brPlaceholder = "{{SAKURA_BR}}"
    private static let linkOpenPlaceholder = "{{SAKURA_LINK_OPEN}}"
    private static let linkMidPlaceholder = "{{SAKURA_LINK_MID}}"
    private static let linkClosePlaceholder = "{{SAKURA_LINK_CLOSE}}"
    private static let boldOpenPlaceholder = "{{SAKURA_BOLD_OPEN}}"
    private static let boldClosePlaceholder = "{{SAKURA_BOLD_CLOSE}}"
    private static let italicOpenPlaceholder = "{{SAKURA_ITALIC_OPEN}}"
    private static let italicClosePlaceholder = "{{SAKURA_ITALIC_CLOSE}}"
    private static let supOpenPlaceholder = "{{SAKURA_SUP_OPEN}}"
    private static let supClosePlaceholder = "{{SAKURA_SUP_CLOSE}}"
    private static let subOpenPlaceholder = "{{SAKURA_SUB_OPEN}}"
    private static let subClosePlaceholder = "{{SAKURA_SUB_CLOSE}}"

    /// Extracts text from a block element, preserving `<br>` tags as newlines
    /// and `<a>` tags as Markdown links.
    private static func textContent(of element: Element) throws -> String {
        var html = try element.html()
        html = html.replacingOccurrences(
            of: "<br\\s*/?>",
            with: brPlaceholder,
            options: .regularExpression
        )
        // Replace <img> tags with image placeholders
        if let imgRegex = try? NSRegularExpression(
            pattern: "<img\\s[^>]*src=[\"']([^\"']+)[\"'][^>]*/?>",
            options: .caseInsensitive
        ) {
            let nsHTML = html as NSString
            let imgMatches = imgRegex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))
            for match in imgMatches.reversed() {
                let urlRange = match.range(at: 1)
                let imgURL = nsHTML.substring(with: urlRange)
                if isLikelyContentImage(imgURL) {
                    let replacement = "\(imgOpenPlaceholder)\(imgURL)\(imgClosePlaceholder)"
                    html = (html as NSString).replacingCharacters(in: match.range, with: replacement)
                } else {
                    html = (html as NSString).replacingCharacters(in: match.range, with: "")
                }
            }
        }
        // Replace <a href="url">text</a> with placeholder-wrapped Markdown
        html = html.replacingOccurrences(
            of: "<a\\s[^>]*href=[\"']([^\"']+)[\"'][^>]*>(.*?)</a>",
            with: "\(linkOpenPlaceholder)$2\(linkMidPlaceholder)$1\(linkClosePlaceholder)",
            options: .regularExpression
        )
        // Replace bold tags with placeholders
        for tag in ["strong", "b"] {
            html = html.replacingOccurrences(
                of: "<\(tag)(?:\\s[^>]*)?>", with: boldOpenPlaceholder,
                options: [.regularExpression, .caseInsensitive]
            )
            html = html.replacingOccurrences(
                of: "</\(tag)>", with: boldClosePlaceholder, options: .caseInsensitive
            )
        }
        // Replace italic tags with placeholders
        html = html.replacingOccurrences(
            of: "<em(?:\\s[^>]*)?>", with: italicOpenPlaceholder,
            options: [.regularExpression, .caseInsensitive]
        )
        html = html.replacingOccurrences(
            of: "</em>", with: italicClosePlaceholder, options: .caseInsensitive
        )
        html = html.replacingOccurrences(
            of: #"<i(?:\s[^>]*)?>"#, with: italicOpenPlaceholder,
            options: [.regularExpression, .caseInsensitive]
        )
        html = html.replacingOccurrences(
            of: "</i>", with: italicClosePlaceholder, options: .caseInsensitive
        )
        // Replace superscript/subscript tags with placeholders
        html = html.replacingOccurrences(
            of: "<sup(?:\\s[^>]*)?>", with: supOpenPlaceholder,
            options: [.regularExpression, .caseInsensitive]
        )
        html = html.replacingOccurrences(
            of: "</sup>", with: supClosePlaceholder, options: .caseInsensitive
        )
        html = html.replacingOccurrences(
            of: "<sub(?:\\s[^>]*)?>", with: subOpenPlaceholder,
            options: [.regularExpression, .caseInsensitive]
        )
        html = html.replacingOccurrences(
            of: "</sub>", with: subClosePlaceholder, options: .caseInsensitive
        )
        let fragment = try SwiftSoup.parseBodyFragment(html)
        var text = try fragment.body()?.text() ?? ""
        text = text.replacingOccurrences(of: brPlaceholder, with: "\n")
        // Convert link placeholders to Markdown [text](url)
        text = text.replacingOccurrences(of: linkOpenPlaceholder, with: "[")
        text = text.replacingOccurrences(of: linkMidPlaceholder, with: "](")
        text = text.replacingOccurrences(of: linkClosePlaceholder, with: ")")
        // Convert formatting placeholders to markdown markers
        text = text.replacingOccurrences(of: boldOpenPlaceholder, with: "**")
        text = text.replacingOccurrences(of: boldClosePlaceholder, with: "**")
        text = text.replacingOccurrences(of: italicOpenPlaceholder, with: "*")
        text = text.replacingOccurrences(of: italicClosePlaceholder, with: "*")
        text = text.replacingOccurrences(of: supOpenPlaceholder, with: "{{SUP}}")
        text = text.replacingOccurrences(of: supClosePlaceholder, with: "{{/SUP}}")
        text = text.replacingOccurrences(of: subOpenPlaceholder, with: "{{SUB}}")
        text = text.replacingOccurrences(of: subClosePlaceholder, with: "{{/SUB}}")
        text = text.replacingOccurrences(of: imgOpenPlaceholder, with: "{{IMG}}")
        text = text.replacingOccurrences(of: imgClosePlaceholder, with: "{{/IMG}}")
        // Validate URLs inside superscript/subscript markers; drop if invalid
        text = stripInvalidURLSupSub(text)
        text = stripRemainingHTMLTags(text)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isLikelyContentImage(_ url: String) -> Bool {
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
    /// Markers with no URL (e.g. plain numbers) are kept as-is.
    private static func stripInvalidURLSupSub(_ text: String) -> String {
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

    /// Strips any remaining HTML tags that may have leaked through parsing.
    private static func stripRemainingHTMLTags(_ text: String) -> String {
        var result = text
        // Remove any HTML tags
        result = result.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        // Decode common HTML entities
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&apos;", with: "'")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        // Collapse excessive whitespace
        result = result.replacingOccurrences(
            of: "[ \\t]+",
            with: " ",
            options: .regularExpression
        )
        // Collapse more than 2 consecutive newlines
        result = result.replacingOccurrences(
            of: "\\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
