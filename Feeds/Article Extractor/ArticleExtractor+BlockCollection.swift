import Foundation
import SwiftSoup

extension ArticleExtractor {

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

    /// Attempts to extract and resolve an image URL from an element's `src` attribute.
    /// Returns the resolved URL string, or nil if the image should be skipped.
    static func extractImageSrc(
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

    // swiftlint:disable function_body_length cyclomatic_complexity
    /// Walks the DOM tree collecting text from block-level elements.
    /// Recurses into non-block wrappers (div, section, etc.) so that
    /// nested blocks like `<div><p>…</p></div>` don't produce duplicates.
    /// Treats leaf divs (divs with no block-level children) as paragraphs.
    static func collectBlocks(
        from element: Element,
        into paragraphs: inout [String],
        baseURL: URL? = nil,
        excludeTitle: String? = nil
    ) throws {
        for child in element.children() {
            let tag = child.tagName().lowercased()
            if tag == "img" || tag == "picture" {
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
                    let suffix = linkSuffix(for: linkHref, baseURL: baseURL)
                    #if DEBUG
                    debugPrint("[Block] <figure> → image: \(resolved)\(suffix.isEmpty ? "" : " (linked)")")
                    #endif
                    paragraphs.append("{{IMG}}\(resolved)\(suffix){{/IMG}}")
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
                let suffix = linkSuffix(for: linkHref, baseURL: baseURL)
                #if DEBUG
                debugPrint("[Block] <a> → linked image: \(resolved)")
                #endif
                paragraphs.append("{{IMG}}\(resolved)\(suffix){{/IMG}}")
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
    // swiftlint:enable function_body_length cyclomatic_complexity

    /// Builds the `{{IMGLINK}}…{{/IMGLINK}}` suffix for an image block when
    /// the image is wrapped in a link.
    static func linkSuffix(for href: String?, baseURL: URL?) -> String {
        guard let href, !href.isEmpty,
              let resolved = resolveURL(href, against: baseURL) else {
            return ""
        }
        return "{{IMGLINK}}\(resolved){{/IMGLINK}}"
    }

    /// Detects non-`<pre>` code block containers (e.g. Code Hike's
    /// `<div class="ch-codeblock">` or GitHub's `<div class="highlight">`).
    static func isCodeBlockWrapper(_ element: Element) -> Bool {
        let className = (try? element.className()) ?? ""
        let codeBlockClasses = [
            "ch-codeblock", "highlight", "code-block",
            "codeblock", "prism-code", "shiki"
        ]
        for cls in codeBlockClasses where className.contains(cls) {
            return true
        }
        return false
    }

    /// A wrapper element (div, section, span, etc.) that contains no nested
    /// block-level or structural children should be treated as a leaf paragraph.
    static func isLeafBlock(_ element: Element) -> Bool {
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
