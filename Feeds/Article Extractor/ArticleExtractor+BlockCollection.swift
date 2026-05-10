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

    /// Walks the DOM collecting text from block-level elements and leaf wrappers.
    static func collectBlocks(
        from element: Element,
        into paragraphs: inout [String],
        baseURL: URL? = nil,
        excludeTitle: String? = nil
    ) throws {
        for child in element.children() {
            try collectBlock(
                from: child,
                into: &paragraphs,
                baseURL: baseURL,
                excludeTitle: excludeTitle
            )
        }
    }

    private static func collectBlock(
        from child: Element,
        into paragraphs: inout [String],
        baseURL: URL?,
        excludeTitle: String?
    ) throws {
        let tag = child.tagName().lowercased()
        if tag == "table" {
            if let marker = tableMarker(from: child, baseURL: baseURL) {
                paragraphs.append(marker)
            }
            return
        }
        if tag == "dl" {
            if let marker = definitionListMarker(from: child, baseURL: baseURL) {
                paragraphs.append(marker)
            }
            return
        }
        if let math = mathMarker(from: child) {
            paragraphs.append(math)
            return
        }
        if tag == "img" || tag == "picture" || tag == "amp-img" {
            collectImageBlock(from: child, tag: tag, baseURL: baseURL, into: &paragraphs)
            return
        }
        if tag == "figure" {
            try collectFigureBlock(from: child, baseURL: baseURL, into: &paragraphs)
            return
        }
        if tag == "a", collectAnchorImage(from: child, baseURL: baseURL, into: &paragraphs) {
            return
        }
        if tag == "pre" || isCodeBlockWrapper(child) {
            try collectCodeBlock(from: child, tag: tag, into: &paragraphs)
            return
        }
        if blockElements.contains(tag) || isLeafBlock(child) {
            try collectTextBlock(
                from: child, tag: tag, baseURL: baseURL,
                excludeTitle: excludeTitle, into: &paragraphs
            )
            return
        }
        log("Block", "<\(tag)> → wrapper, recursing into children")
        try collectBlocks(from: child, into: &paragraphs,
                          baseURL: baseURL, excludeTitle: excludeTitle)
    }

    private static func collectImageBlock(
        from child: Element, tag: String, baseURL: URL?, into paragraphs: inout [String]
    ) {
        if let resolved = extractImageSrc(from: child, tag: tag, baseURL: baseURL) {
            log("Block", "<\(tag)> → image: \(resolved)")
            paragraphs.append("{{IMG}}\(resolved){{/IMG}}")
        } else {
            log("Block", "<\(tag)> → skipped (no valid src)")
        }
    }

    private static func collectFigureBlock(
        from child: Element, baseURL: URL?, into paragraphs: inout [String]
    ) throws {
        if let resolved = extractImageSrc(from: child, tag: "figure", baseURL: baseURL) {
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
    }

    private static func collectAnchorImage(
        from child: Element, baseURL: URL?, into paragraphs: inout [String]
    ) -> Bool {
        guard let imgChild = try? child.select("img, picture").first(),
              let resolved = extractImageSrc(
                from: imgChild,
                tag: imgChild.tagName().lowercased(),
                baseURL: baseURL
              ) else { return false }
        let linkHref = try? child.attr("href")
        let suffix = linkSuffix(for: linkHref, baseURL: baseURL)
        log("Block", "<a> → linked image: \(resolved)")
        paragraphs.append("{{IMG}}\(resolved)\(suffix){{/IMG}}")
        return true
    }

    private static func collectCodeBlock(
        from child: Element, tag: String, into paragraphs: inout [String]
    ) throws {
        let codeText = try codeContent(of: child)
        if !codeText.isEmpty {
            log("Block", "<\(tag)> → code block (\(codeText.count) chars)")
            paragraphs.append("{{CODE}}\(codeText){{/CODE}}")
        } else {
            log("Block", "<\(tag)> → empty code block, skipped")
        }
    }

    private static func collectTextBlock(
        from child: Element,
        tag: String,
        baseURL: URL?,
        excludeTitle: String?,
        into paragraphs: inout [String]
    ) throws {
        // Skip textContent for embed-marker paragraphs so
        // ArticleMarker.escape doesn't mangle the delimiters.
        if let rawText = try? child.text(),
           let marker = embedMarkerParagraph(rawText) {
            paragraphs.append(marker)
            return
        }
        var text = try textContent(of: child, baseURL: baseURL)
        guard !text.isEmpty else {
            log("Block", "<\(tag)> → empty text, skipped")
            return
        }
        let headingTags = ["h1", "h2", "h3", "h4", "h5", "h6"]
        if headingTags.contains(tag),
           let excludeTitle,
           text.caseInsensitiveCompare(excludeTitle) == .orderedSame {
            log("Block", "<\(tag)> → skipped (matches article title)")
            return
        }
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
    /// `<table>` and `<pre>` always trigger non-leaf behavior so they are not flattened
    /// into their wrapper's text content.
    static func isLeafBlock(_ element: Element) -> Bool {
        let structuralTags: Set<String> = ["div", "section", "article", "main", "aside"]
        let specialTags: Set<String> = ["table", "pre", "dl"]
        for child in element.children() {
            let tag = child.tagName().lowercased()
            if blockElements.contains(tag)
                || structuralTags.contains(tag)
                || specialTags.contains(tag)
                || isCodeBlockWrapper(child) {
                return false
            }
        }
        let text = (try? element.text()) ?? ""
        return !text.isEmpty
    }
}
