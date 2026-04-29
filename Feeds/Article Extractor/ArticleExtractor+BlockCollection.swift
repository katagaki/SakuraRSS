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

        log("Extract", "collectBlocks produced \(paragraphs.count) blocks")
        for (index, block) in paragraphs.enumerated() {
            if block.hasPrefix("{{IMG}}") {
                log("Extract", "  [\(index)] image: \(block.prefix(120))")
            } else if block.hasPrefix("{{CODE}}") {
                log("Extract", "  [\(index)] code (\(block.count) chars)")
            } else {
                log("Extract", "  [\(index)] text (\(block.count) chars): \(block.prefix(80))")
            }
        }

        if paragraphs.isEmpty {
            let text = try textContent(of: element, baseURL: baseURL)
            if text.isEmpty { return [] }
            let split = text.components(separatedBy: "\n\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return split.isEmpty ? [text] : split
        }

        return paragraphs
    }

    /// Extracts and resolves the best image URL from an `<img>`, `<amp-img>`, or `<picture>`.
    static func extractImageSrc(
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
            log("Image", "Skipped non-content <\(tag)>: \(src)")
            return nil
        }
        guard let resolved = resolveURL(src, against: baseURL) else {
            return nil
        }
        log("Image", "Extracted <\(tag)>: \(resolved)")
        return resolved
    }

    // swiftlint:disable function_body_length cyclomatic_complexity
    /// Walks the DOM collecting text from block-level elements and leaf wrappers.
    static func collectBlocks(
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
                    log("Block", "<\(tag)> → image: \(resolved)")
                    paragraphs.append("{{IMG}}\(resolved){{/IMG}}")
                } else {
                    log("Block", "<\(tag)> → skipped (no valid src)")
                }
            } else if tag == "figure" {
                if let resolved = extractImageSrc(from: child, tag: tag, baseURL: baseURL) {
                    let linkHref = try? child.select("a[href]").first()?.attr("href")
                    let suffix = linkSuffix(for: linkHref, baseURL: baseURL)
                    log("Block", "<figure> → image: \(resolved)\(suffix.isEmpty ? "" : " (linked)")")
                    paragraphs.append("{{IMG}}\(resolved)\(suffix){{/IMG}}")
                } else {
                    log("Block", "<figure> → skipped (no valid image)")
                }
                if let caption = try? child.select("figcaption").first() {
                    let captionText = try textContent(of: caption, baseURL: baseURL)
                    if !captionText.isEmpty {
                        log("Block", "<figcaption> → \(captionText.prefix(80))")
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
                log("Block", "<a> → linked image: \(resolved)")
                paragraphs.append("{{IMG}}\(resolved)\(suffix){{/IMG}}")
            } else if tag == "pre" || isCodeBlockWrapper(child) {
                let codeText = try codeContent(of: child)
                if !codeText.isEmpty {
                    log("Block", "<\(tag)> → code block (\(codeText.count) chars)")
                    paragraphs.append("{{CODE}}\(codeText){{/CODE}}")
                } else {
                    log("Block", "<\(tag)> → empty code block, skipped")
                }
            } else if blockElements.contains(tag) || isLeafBlock(child) {
                // Skip textContent for embed-marker paragraphs so
                // ArticleMarker.escape doesn't mangle the delimiters.
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
                        log("Block", "<\(tag)> → skipped (matches article title)")
                    } else {
                        switch tag {
                        case "h1": text = "# \(text)"
                        case "h2": text = "## \(text)"
                        case "h3": text = "### \(text)"
                        case "h4", "h5", "h6": text = "**\(text)**"
                        default: break
                        }
                        let kind = isLeafBlock(child) && !blockElements.contains(tag) ? "leaf" : tag
                        log("Block", "<\(kind)> → text (\(text.count) chars): \(text.prefix(80))")
                        paragraphs.append(text)
                    }
                } else {
                    log("Block", "<\(tag)> → empty text, skipped")
                }
            } else {
                log("Block", "<\(tag)> → wrapper, recursing into children")
                try collectBlocks(from: child, into: &paragraphs,
                                  baseURL: baseURL, excludeTitle: excludeTitle)
            }
        }
    }
    // swiftlint:enable function_body_length cyclomatic_complexity

    /// Builds an `{{IMGLINK}}` suffix when an image is wrapped in a link.
    static func linkSuffix(for href: String?, baseURL: URL?) -> String {
        guard let href, !href.isEmpty,
              let resolved = resolveURL(href, against: baseURL) else {
            return ""
        }
        return "{{IMGLINK}}\(resolved){{/IMGLINK}}"
    }

    /// Detects non-`<pre>` code block containers like `.ch-codeblock` or `.highlight`.
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

    /// True when a wrapper has no block-level or structural children and should be a paragraph.
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
