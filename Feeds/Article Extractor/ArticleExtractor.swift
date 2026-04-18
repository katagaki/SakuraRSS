import Foundation
import SwiftSoup

/// When changing extraction logic, bump `ParserVersion.articleExtractor`
/// to invalidate cached article content on next launch.
struct ArticleExtractor {

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
            // Promote social embeds (YouTube, X) into marker paragraphs
            // before noise removal so selectors targeting twitter-tweet
            // blockquotes and iframes don't strip the content entirely.
            promoteInlineEmbeds(in: doc, baseURL: baseURL)
            removeNoise(from: doc)
            let element = try findMainContent(from: doc)
            removeNoise(from: element)
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
            var request = URLRequest(url: url)
            request.setValue(
                sakuraUserAgent,
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
}
