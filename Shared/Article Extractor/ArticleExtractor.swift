import Foundation
import SwiftSoup

/// When changing extraction logic, bump `ParserVersion.articleExtractor`
/// to invalidate cached article content on next launch.
struct ArticleExtractor { // swiftlint:disable:this type_body_length

    static let contentSelectors = [
        // High-precision schema.org / semantic markup - check first
        "[itemprop=articleBody]",
        "[itemprop=reviewBody]",
        "[itemprop=text]",
        "[data-testid=article-body]",
        "[data-component=text-block]",
        // Common CMS / framework selectors
        "article",
        "[role=main]",
        "main",
        ".post-content",
        ".entry-content",
        ".article-body",
        ".article-content",
        ".article__content",
        ".article__body",
        ".post-body",
        ".post__content",
        ".story-body",
        ".story-body__inner",
        ".story__body",
        ".content-body",
        ".content__article-body",
        ".rich-text",
        ".prose",
        "#article-body",
        "#articleBody",
        "#singleBody",
        "#content",
        "#main-content",
        ".contenuto",
        ".post",
        ".entry"
    ]

    static let blockElements = [
        "p", "h1", "h2", "h3", "h4", "h5", "h6",
        "blockquote", "li", "figcaption", "pre", "td", "th"
    ]

    /// Parses HTML and returns both the extracted text and structured
    /// metadata (author, date, lead image).  Metadata is captured *before*
    /// noise removal so byline strippers don't erase the byline first.
    static func extractArticle(
        fromHTML html: String,
        baseURL: URL? = nil,
        excludeTitle: String? = nil
    ) -> ExtractionResult {
        guard !html.isEmpty else { return ExtractionResult() }

        // Fast-paths for plain-text / thin-wrapper HTML bypass the DOM.
        if !html.contains("<") {
            let text = extractText(fromHTML: html, baseURL: baseURL, excludeTitle: excludeTitle)
            return ExtractionResult(text: text)
        }

        let doc: Document
        do {
            doc = try SwiftSoup.parse(html)
        } catch {
            return ExtractionResult()
        }

        let paywalled = PaywallDetector.htmlSuggestsPaywall(html)

        if let baseURL,
           let adapter = SiteAdapterRegistry.adapter(for: baseURL),
           var result = adapter.extract(
            document: doc,
            baseURL: baseURL,
            excludeTitle: excludeTitle
           ),
           let text = result.text, !text.isEmpty {
            result.paywalled = result.paywalled || paywalled
            return result
        }

        let metadata = extractMetadata(from: doc)
        let text = extractText(
            fromHTML: html,
            baseURL: baseURL,
            excludeTitle: excludeTitle
        )
        return ExtractionResult(
            text: text,
            metadata: metadata,
            paywalled: paywalled
        )
    }

    static func extractText(
        fromHTML html: String,
        baseURL: URL? = nil,
        excludeTitle: String? = nil
    ) -> String? {
        guard !html.isEmpty else {
            #if DEBUG
            debugPrint("[Extract] extractText: empty HTML, returning nil")
            #endif
            return nil
        }

        // If the content has no HTML tags, it's likely already plain text
        // or Markdown - return it directly instead of parsing as HTML.
        if !html.contains("<") {
            var trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
            trimmed = resolveMarkdownLinks(in: trimmed, baseURL: baseURL)
            trimmed = ArticleMarker.escape(trimmed)
            #if DEBUG
            debugPrint("[Extract] extractText: no HTML tags, plain text (\(trimmed.count) chars)")
            #endif
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
            debugPrint("[Extract] extractText: wrapped plain text/Markdown (\(tagCount) tags, \(stripped.count) chars), using directly")
            #endif
            var cleaned = stripRemainingHTMLTags(html)
            cleaned = resolveMarkdownLinks(in: cleaned, baseURL: baseURL)
            return ArticleMarker.escape(cleaned)
        }

        #if DEBUG
        debugPrint("[Extract] extractText: full HTML (\(tagCount) tags, \(html.count) chars), parsing with SwiftSoup")
        #endif

        do {
            let doc = try SwiftSoup.parse(html)
            normalizeAMPElements(in: doc)
            // Promote social embeds (YouTube, X) into marker paragraphs
            // before noise removal so selectors targeting twitter-tweet
            // blockquotes and iframes don't strip the content entirely.
            promoteInlineEmbeds(in: doc, baseURL: baseURL)
            removeNoise(from: doc, scope: .global)
            let element = try findMainContent(from: doc)
            removeNoise(from: element, scope: .local)
            let rawParagraphs = try extractParagraphs(from: element,
                                                      baseURL: baseURL,
                                                      excludeTitle: excludeTitle)
            let paragraphs = rawParagraphs.filter { !isAdvertisementText($0) }
            let result = paragraphs.joined(separator: "\n\n")
            var cleaned = stripRemainingHTMLTags(result)
            cleaned = resolveMarkdownLinks(in: cleaned, baseURL: baseURL)
            cleaned = compactWhitespace(in: cleaned)
            #if DEBUG
            debugPrint("[Extract] extractText: SwiftSoup produced \(paragraphs.count) paragraphs (\(cleaned.count) chars)")
            #endif
            return cleaned.isEmpty ? nil : cleaned
        } catch {
            #if DEBUG
            debugPrint("[Extract] extractText: SwiftSoup parse failed: \(error)")
            #endif
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
            let request = URLRequest.sakura(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let html = HTMLDataDecoder.decode(data, response: response) else {
                return nil
            }
            return extractText(fromHTML: html, baseURL: url, excludeTitle: excludeTitle)
        } catch {
            return nil
        }
    }

    /// URL-based fetch that also surfaces paywall, metadata, and raw HTML
    /// signals so the caller can decide whether to escalate to WebView.
    static func extractArticle(
        fromURL url: URL,
        excludeTitle: String? = nil
    ) async -> ExtractionResult {
        if WebViewExtractor.requiresWebView(for: url) {
            let extractor = WebViewExtractor()
            if let text = await extractor.extractText(from: url) {
                return ExtractionResult(text: text)
            }
        }

        do {
            let request = URLRequest.sakura(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let html = HTMLDataDecoder.decode(data, response: response) else {
                return ExtractionResult()
            }
            if BotChallengeDetector.looksLikeChallenge(html) {
                if let webText = await WebViewExtractor().extractText(from: url) {
                    return ExtractionResult(text: webText)
                }
                return ExtractionResult()
            }
            var result = extractArticle(
                fromHTML: html,
                baseURL: url,
                excludeTitle: excludeTitle
            )
            if !result.paywalled,
               PaywallDetector.detect(response: response, extractedText: result.text) {
                result.paywalled = true
            }
            return result
        } catch {
            return ExtractionResult()
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

        #if DEBUG
        debugPrint("[Extract] collectBlocks produced \(paragraphs.count) blocks")
        for (index, block) in paragraphs.enumerated() {
            if block.hasPrefix("{{IMG}}") {
                debugPrint("[Extract]   [\(index)] image: \(block.prefix(120))")
            } else if block.hasPrefix("{{CODE}}") {
                debugPrint("[Extract]   [\(index)] code (\(block.count) chars)")
            } else {
                debugPrint("[Extract]   [\(index)] text (\(block.count) chars): \(block.prefix(80))")
            }
        }
        #endif

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
    private static func extractImageSrc(
        from element: Element, tag: String, baseURL: URL?
    ) -> String? {
        let imageLike: Set<String> = ["img", "amp-img", "picture"]
        let imgElement: Element?
        if imageLike.contains(tag) {
            imgElement = element
        } else {
            imgElement = try? element.select("img, amp-img, picture").first()
        }
        guard let imgElement,
              let src = bestImageURL(from: imgElement), !src.isEmpty else {
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

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private static func collectBlocks(
        from element: Element,
        into paragraphs: inout [String],
        baseURL: URL? = nil,
        excludeTitle: String? = nil
    ) throws {
        for child in element.children() {
            let tag = child.tagName().lowercased()
            if tag == "table" {
                if let marker = tableMarker(from: child, baseURL: baseURL) {
                    paragraphs.append(marker)
                }
                continue
            }
            if let mathMarker = mathMarker(from: child) {
                paragraphs.append(mathMarker)
                continue
            }
            if tag == "img" || tag == "picture" || tag == "amp-img" {
                if let resolved = extractImageSrc(from: child, tag: tag, baseURL: baseURL) {
                    #if DEBUG
                    debugPrint("[Block] <\(tag)> → image: \(resolved)")
                    #endif
                    paragraphs.append("{{IMG}}\(resolved){{/IMG}}")
                } else {
                    #if DEBUG
                    debugPrint("[Block] <\(tag)> → skipped (no valid src)")
                    #endif
                }
            } else if tag == "figure" {
                if let resolved = extractImageSrc(from: child, tag: tag, baseURL: baseURL) {
                    // Check if the image inside the figure is wrapped in a link
                    let linkHref = try? child.select("a[href]").first()?.attr("href")
                    let linkSuffix = linkSuffix(for: linkHref, baseURL: baseURL)
                    #if DEBUG
                    debugPrint("[Block] <figure> → image: \(resolved)\(linkSuffix.isEmpty ? "" : " (linked)")")
                    #endif
                    paragraphs.append("{{IMG}}\(resolved)\(linkSuffix){{/IMG}}")
                } else {
                    #if DEBUG
                    debugPrint("[Block] <figure> → skipped (no valid image)")
                    #endif
                }
                if let caption = try? child.select("figcaption").first() {
                    let captionText = try textContent(of: caption, baseURL: baseURL)
                    if !captionText.isEmpty {
                        #if DEBUG
                        debugPrint("[Block] <figcaption> → \(captionText.prefix(80))")
                        #endif
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
                #if DEBUG
                debugPrint("[Block] <a> → linked image: \(resolved)")
                #endif
                paragraphs.append("{{IMG}}\(resolved)\(linkSuffix){{/IMG}}")
            } else if tag == "pre" || isCodeBlockWrapper(child) {
                let codeText = try codeContent(of: child)
                if !codeText.isEmpty {
                    #if DEBUG
                    debugPrint("[Block] <\(tag)> → code block (\(codeText.count) chars)")
                    #endif
                    paragraphs.append("{{CODE}}\(codeText){{/CODE}}")
                } else {
                    #if DEBUG
                    debugPrint("[Block] <\(tag)> → empty code block, skipped")
                    #endif
                }
            } else if blockElements.contains(tag) || isLeafBlock(child) {
                // Fast-path: paragraphs injected by `promoteInlineEmbeds`
                // contain only an embed marker.  Skip `textContent` so
                // `ArticleMarker.escape` doesn't mangle the marker delimiters.
                if let rawText = try? child.text(),
                   let marker = embedMarkerParagraph(rawText) {
                    paragraphs.append(marker)
                    continue
                }
                var text = try textContent(of: child, baseURL: baseURL)
                if !text.isEmpty {
                    let headingTags = ["h1", "h2", "h3", "h4", "h5", "h6"]
                    if headingTags.contains(tag),
                       let excludeTitle,
                       text.caseInsensitiveCompare(excludeTitle) == .orderedSame {
                        #if DEBUG
                        debugPrint("[Block] <\(tag)> → skipped (matches article title)")
                        #endif
                    } else {
                        switch tag {
                        case "h1": text = "# \(text)"
                        case "h2": text = "## \(text)"
                        case "h3": text = "### \(text)"
                        case "h4", "h5", "h6": text = "**\(text)**"
                        default: break
                        }
                        #if DEBUG
                        let kind = isLeafBlock(child) && !blockElements.contains(tag) ? "leaf" : tag
                        debugPrint("[Block] <\(kind)> → text (\(text.count) chars): \(text.prefix(80))")
                        #endif
                        paragraphs.append(text)
                    }
                } else {
                    #if DEBUG
                    debugPrint("[Block] <\(tag)> → empty text, skipped")
                    #endif
                }
            } else {
                #if DEBUG
                debugPrint("[Block] <\(tag)> → wrapper, recursing into children")
                #endif
                try collectBlocks(from: child, into: &paragraphs,
                                  baseURL: baseURL, excludeTitle: excludeTitle)
            }
        }
    }

    /// Resolves a potentially relative URL string against a base URL.
    /// Returns the resolved absolute URL string, or nil if it can't be resolved.
    static func resolveURL(_ src: String, against baseURL: URL?) -> String? {
        let decoded = htmlEntityDecodedURL(src)
        // Already absolute
        if let _ = URL(string: decoded),
           decoded.hasPrefix("http://") || decoded.hasPrefix("https://") {
            return stripTrackingParameters(from: decoded)
        }
        // Protocol-relative
        if decoded.hasPrefix("//"), let url = URL(string: "https:\(decoded)") {
            return stripTrackingParameters(from: url.absoluteString)
        }
        // Relative - needs base URL
        if let baseURL, let resolved = URL(string: decoded, relativeTo: baseURL) {
            return stripTrackingParameters(from: resolved.absoluteString)
        }
        return nil
    }

    /// Percent-decodes bare `&amp;` / `&#x26;` entity sequences commonly
    /// left in raw attribute values before handing the string to `URL`.
    private static func htmlEntityDecodedURL(_ src: String) -> String {
        guard src.contains("&") else { return src }
        return src
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#x26;", with: "&")
            .replacingOccurrences(of: "&#38;", with: "&")
    }

    private static let trackingParameterPrefixes: Set<String> = [
        "utm_", "mc_", "fbclid", "gclid", "dclid",
        "igshid", "oly_anon_id", "oly_enc_id", "ref_",
        "spm", "sourceid", "gs_lcrp"
    ]

    /// Strips known tracking query parameters while preserving everything
    /// else.  Improves cache-hit rate for images that differ only in their
    /// utm_* tags between pages.
    static func stripTrackingParameters(from absoluteString: String) -> String {
        guard var components = URLComponents(string: absoluteString),
              let queryItems = components.queryItems, !queryItems.isEmpty else {
            return absoluteString
        }
        let filtered = queryItems.filter { item in
            let lowered = item.name.lowercased()
            if trackingParameterPrefixes.contains(where: lowered.hasPrefix) {
                return false
            }
            return lowered != "fbclid" && lowered != "gclid"
                && lowered != "dclid" && lowered != "igshid"
        }
        components.queryItems = filtered.isEmpty ? nil : filtered
        return components.string ?? absoluteString
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

    /// Detects non-`<pre>` code block containers (e.g. Code Hike's
    /// `<div class="ch-codeblock">` or GitHub's `<div class="highlight">`).
    private static func isCodeBlockWrapper(_ element: Element) -> Bool {
        let className = (try? element.className()) ?? ""
        let codeBlockClasses = [
            "ch-codeblock", "highlight", "code-block",
            "codeblock", "prism-code", "shiki"
        ]
        for cls in codeBlockClasses {
            if className.contains(cls) {
                return true
            }
        }
        return false
    }

    /// Extracts the raw text content from a code block element (`<pre>`,
    /// or a code block wrapper div), preserving whitespace and newlines.
    static func codeContent(of element: Element) throws -> String {
        // Find the innermost code element, or use the element itself
        let source: Element
        if let codeChild = try? element.select("code").first() {
            source = codeChild
        } else if let preChild = try? element.select("pre").first() {
            source = preChild
        } else {
            source = element
        }

        // For elements with line-oriented children (e.g. Code Hike uses
        // <div> per line inside <code>), extract text line by line.
        let directDivs = source.children().filter {
            $0.tagName().lowercased() == "div"
        }
        if directDivs.count > 1 {
            let lines = try directDivs.map { try $0.text() }
            let text = lines.joined(separator: "\n")
            let decoded = decodeCodeEntities(text)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\n"))
            return ArticleMarker.escape(decoded)
        }

        // Standard <pre>/<pre><code> - use inner HTML
        var html = try source.html()
        html = html.replacingOccurrences(
            of: #"<br\s*/?>"#, with: "\n", options: .regularExpression
        )
        html = html.replacingOccurrences(
            of: "<[^>]+>", with: "", options: .regularExpression
        )
        let decoded = decodeCodeEntities(html)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\n"))
        return ArticleMarker.escape(decoded)
    }

    private static func decodeCodeEntities(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&apos;", with: "'")
        result = result.replacingOccurrences(of: "&#x27;", with: "'")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        return result
    }

    /// Resolves relative URLs inside Markdown links (`[text](url)`) against a base URL.
    /// Also percent-encodes spaces in link URLs.
    static func resolveMarkdownLinks(in text: String, baseURL: URL?) -> String {
        guard let baseURL else { return text }
        let pattern = #"\[([^\]]*)\]\(([^)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        var result = text
        let nsText = result as NSString
        let matches = regex.matches(in: result, range: NSRange(location: 0, length: nsText.length))
        for match in matches.reversed() {
            var url = nsText.substring(with: match.range(at: 2))
            if url.hasPrefix("http://") || url.hasPrefix("https://") { continue }
            url = url.replacingOccurrences(of: " ", with: "%20")
            if url.hasPrefix("//"), let abs = URL(string: "https:\(url)") {
                url = abs.absoluteString
            } else if let resolved = URL(string: url, relativeTo: baseURL) {
                url = resolved.absoluteString
            } else {
                continue
            }
            let linkText = nsText.substring(with: match.range(at: 1))
            let replacement = "[\(linkText)](\(url))"
            result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
        }
        return result
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
