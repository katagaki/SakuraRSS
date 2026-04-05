import Foundation
import SwiftSoup

struct ArticleExtractor {

    static let contentSelectors = [
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

    static let blockElements = [
        "p", "h1", "h2", "h3", "h4", "h5", "h6",
        "blockquote", "li", "figcaption", "pre", "td", "th"
    ]

    static func extractText(
        fromHTML html: String,
        baseURL: URL? = nil,
        excludeTitle: String? = nil
    ) -> String? {
        guard !html.isEmpty else { return nil }
        do {
            let doc = try SwiftSoup.parse(html)
            removeNoise(from: doc)
            let element = try findMainContent(from: doc)
            removeNoise(from: element)
            let paragraphs = try extractParagraphs(from: element,
                                                   baseURL: baseURL,
                                                   excludeTitle: excludeTitle)
            let result = paragraphs.joined(separator: "\n\n")
            let cleaned = stripRemainingHTMLTags(result)
            return cleaned.isEmpty ? nil : cleaned
        } catch {
            return nil
        }
    }

    static func extractText(
        fromURL url: URL,
        excludeTitle: String? = nil
    ) async -> String? {
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
            return extractText(fromHTML: html, baseURL: url, excludeTitle: excludeTitle)
        } catch {
            return nil
        }
    }

    // MARK: - Content Discovery

    static func findMainContent(from doc: Document) throws -> Element {
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

    // MARK: - Paragraph Extraction

    static func extractParagraphs(
        from element: Element,
        baseURL: URL? = nil,
        excludeTitle: String? = nil
    ) throws -> [String] {
        var paragraphs: [String] = []
        try collectBlocks(from: element, into: &paragraphs,
                          baseURL: baseURL, excludeTitle: excludeTitle)

        if paragraphs.isEmpty {
            let text = try textContent(of: element, baseURL: baseURL)
            return text.isEmpty ? [] : [text]
        }

        return paragraphs
    }

    /// Walks the DOM tree collecting text from block-level elements.
    /// Recurses into non-block wrappers (div, section, etc.) so that
    /// nested blocks like `<div><p>…</p></div>` don't produce duplicates.
    /// Treats leaf divs (divs with no block-level children) as paragraphs.
    private static func collectBlocks(
        from element: Element,
        into paragraphs: inout [String],
        baseURL: URL? = nil,
        excludeTitle: String? = nil
    ) throws {
        for child in element.children() {
            let tag = child.tagName().lowercased()
            if tag == "img" {
                if let src = try? child.attr("src"), !src.isEmpty, isLikelyContentImage(src),
                   let resolved = resolveURL(src, against: baseURL) {
                    paragraphs.append("{{IMG}}\(resolved){{/IMG}}")
                }
            } else if tag == "picture" {
                if let img = try? child.select("img").first(),
                   let src = try? img.attr("src"), !src.isEmpty, isLikelyContentImage(src),
                   let resolved = resolveURL(src, against: baseURL) {
                    paragraphs.append("{{IMG}}\(resolved){{/IMG}}")
                }
            } else if tag == "figure" {
                if let img = try? child.select("img").first(),
                   let src = try? img.attr("src"), !src.isEmpty, isLikelyContentImage(src),
                   let resolved = resolveURL(src, against: baseURL) {
                    paragraphs.append("{{IMG}}\(resolved){{/IMG}}")
                }
                if let caption = try? child.select("figcaption").first() {
                    let captionText = try textContent(of: caption, baseURL: baseURL)
                    if !captionText.isEmpty {
                        paragraphs.append("*\(captionText)*")
                    }
                }
            } else if blockElements.contains(tag) || isLeafBlock(child) {
                var text = try textContent(of: child, baseURL: baseURL)
                if !text.isEmpty {
                    let headingTags = ["h1", "h2", "h3", "h4", "h5", "h6"]
                    if headingTags.contains(tag),
                       let excludeTitle,
                       text.caseInsensitiveCompare(excludeTitle) == .orderedSame {
                        // Skip headers that match the article title
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
                                  baseURL: baseURL, excludeTitle: excludeTitle)
            }
        }
    }

    /// Resolves a potentially relative URL string against a base URL.
    /// Returns the resolved absolute URL string, or nil if it can't be resolved.
    static func resolveURL(_ src: String, against baseURL: URL?) -> String? {
        // Already absolute
        if let _ = URL(string: src), src.hasPrefix("http://") || src.hasPrefix("https://") {
            return src
        }
        // Protocol-relative
        if src.hasPrefix("//"), let url = URL(string: "https:\(src)") {
            return url.absoluteString
        }
        // Relative — needs base URL
        if let baseURL, let resolved = URL(string: src, relativeTo: baseURL) {
            return resolved.absoluteString
        }
        return nil
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
}
