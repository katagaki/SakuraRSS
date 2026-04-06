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

        // If the content has no HTML tags, it's likely already plain text
        // or Markdown — return it directly instead of parsing as HTML.
        if !html.contains("<") {
            let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        // If the HTML is just a thin wrapper (e.g. <div>) around plain text
        // or Markdown, strip the wrapper and return the inner text directly.
        // This avoids SwiftSoup collapsing all newlines.
        let stripped = html.replacingOccurrences(
            of: "<[^>]+>", with: "", options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        let tagCount = html.components(separatedBy: "<").count - 1
        let hasMultipleNewlines = html.contains("\n\n")
        if hasMultipleNewlines && tagCount <= 4 && !stripped.isEmpty {
            #if DEBUG
            debugPrint("[Extract] Content looks like wrapped plain text/Markdown (\(tagCount) tags), using directly")
            #endif
            return stripRemainingHTMLTags(html)
        }

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
            var request = URLRequest(url: url)
            request.setValue(
                "Mozilla/5.0 (compatible; SakuraRSS/1.0)",
                forHTTPHeaderField: "User-Agent"
            )
            let (data, _) = try await URLSession.shared.data(for: request)
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
            if text.isEmpty { return [] }
            // If the text contains paragraph breaks (e.g. Markdown content
            // or text with <br><br>), split into separate paragraphs.
            let split = text.components(separatedBy: "\n\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return split.isEmpty ? [text] : split
        }

        return paragraphs
    }

    /// Walks the DOM tree collecting text from block-level elements.
    /// Recurses into non-block wrappers (div, section, etc.) so that
    /// nested blocks like `<div><p>…</p></div>` don't produce duplicates.
    /// Treats leaf divs (divs with no block-level children) as paragraphs.
    /// Attempts to extract and resolve an image URL from an element's `src` attribute.
    /// Returns the resolved URL string, or nil if the image should be skipped.
    private static func extractImageSrc( // swiftlint:disable:this cyclomatic_complexity
        from element: Element, tag: String, baseURL: URL?
    ) -> String? {
        let imgElement: Element?
        if tag == "img" {
            imgElement = element
        } else {
            imgElement = try? element.select("img").first()
        }
        guard let imgElement,
              let src = try? imgElement.attr("src"), !src.isEmpty else {
            return nil
        }
        guard isLikelyContentImage(src) else {
            #if DEBUG
            debugPrint("[Image] Skipped non-content <\(tag)>: \(src)")
            #endif
            return nil
        }
        guard let resolved = resolveURL(src, against: baseURL) else {
            return nil
        }
        #if DEBUG
        debugPrint("[Image] Extracted <\(tag)>: \(resolved)")
        #endif
        return resolved
    }

    private static func collectBlocks(
        from element: Element,
        into paragraphs: inout [String],
        baseURL: URL? = nil,
        excludeTitle: String? = nil
    ) throws {
        for child in element.children() {
            let tag = child.tagName().lowercased()
            if tag == "img" || tag == "picture" {
                if let resolved = extractImageSrc(from: child, tag: tag, baseURL: baseURL) {
                    paragraphs.append("{{IMG}}\(resolved){{/IMG}}")
                }
            } else if tag == "figure" {
                if let resolved = extractImageSrc(from: child, tag: tag, baseURL: baseURL) {
                    // Check if the image inside the figure is wrapped in a link
                    let linkHref = try? child.select("a[href]").first()?.attr("href")
                    let linkSuffix = linkSuffix(for: linkHref, baseURL: baseURL)
                    paragraphs.append("{{IMG}}\(resolved)\(linkSuffix){{/IMG}}")
                }
                if let caption = try? child.select("figcaption").first() {
                    let captionText = try textContent(of: caption, baseURL: baseURL)
                    if !captionText.isEmpty {
                        paragraphs.append("*\(captionText)*")
                    }
                }
            } else if tag == "a",
                      let imgChild = try? child.select("img, picture").first(),
                      let resolved = extractImageSrc(
                        from: imgChild,
                        tag: imgChild.tagName().lowercased(),
                        baseURL: baseURL
                      ) {
                let linkHref = try? child.attr("href")
                let linkSuffix = linkSuffix(for: linkHref, baseURL: baseURL)
                paragraphs.append("{{IMG}}\(resolved)\(linkSuffix){{/IMG}}")
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
            #if DEBUG
            debugPrint("[Image] Resolved protocol-relative URL: \(src) -> \(url.absoluteString)")
            #endif
            return url.absoluteString
        }
        // Relative — needs base URL
        if let baseURL, let resolved = URL(string: src, relativeTo: baseURL) {
            #if DEBUG
            debugPrint("[Image] Resolved relative URL: \(src) -> \(resolved.absoluteString) (base: \(baseURL.absoluteString))")
            #endif
            return resolved.absoluteString
        }
        #if DEBUG
        debugPrint("[Image] Failed to resolve URL: \(src) (base: \(baseURL?.absoluteString ?? "nil"))")
        #endif
        return nil
    }

    /// Builds the `{{IMGLINK}}…{{/IMGLINK}}` suffix for an image block when
    /// the image is wrapped in a link.
    private static func linkSuffix(for href: String?, baseURL: URL?) -> String {
        guard let href, !href.isEmpty,
              let resolved = resolveURL(href, against: baseURL) else {
            return ""
        }
        return "{{IMGLINK}}\(resolved){{/IMGLINK}}"
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
