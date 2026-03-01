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
        ".menu",
        ".breadcrumb",
        ".social-share",
        ".share-buttons",
        ".related-posts",
        ".comments",
        ".advertisement",
        ".ad-container",
        "[role=navigation]",
        "[role=banner]",
        "[role=complementary]",
        "[role=contentinfo]",
        "script",
        "style",
        "noscript",
        "iframe"
    ]

    private static let blockElements = [
        "p", "h1", "h2", "h3", "h4", "h5", "h6",
        "blockquote", "li", "figcaption", "pre"
    ]

    static func extractText(fromHTML html: String) -> String? {
        guard !html.isEmpty else { return nil }
        do {
            let doc = try SwiftSoup.parse(html)
            removeNoise(from: doc)
            let element = try findMainContent(from: doc)
            let paragraphs = try extractParagraphs(from: element)
            let result = paragraphs.joined(separator: "\n\n")
            return result.isEmpty ? nil : result
        } catch {
            return nil
        }
    }

    static func extractText(fromURL url: URL) async -> String? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else {
                return nil
            }
            return extractText(fromHTML: html)
        } catch {
            return nil
        }
    }

    // MARK: - Private Helpers

    private static func removeNoise(from doc: Document) {
        for selector in noiseSelectors {
            do {
                let elements = try doc.select(selector)
                try elements.remove()
            } catch {
                continue
            }
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

    private static func extractParagraphs(from element: Element) throws -> [String] {
        let selector = blockElements.joined(separator: ", ")
        let blocks = try element.select(selector)

        if blocks.isEmpty() {
            let text = try element.text()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? [] : [text]
        }

        var paragraphs: [String] = []
        for block in blocks {
            let text = try block.text()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                paragraphs.append(text)
            }
        }
        return paragraphs
    }
}
