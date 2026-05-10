import Foundation

public extension ContentResolver {

    /// Honors the per-feed `articleSource-<feedID>` UserDefaults setting,
    /// or the explicit override passed in by the Open Article extension.
    /// Returns `true` if the source mode handled extraction (success or
    /// definitive failure) and the cascade should stop.
    func extractFromSpecificSource(_ source: ArticleSource) async -> Bool {
        switch source {
        case .feedText:
            return extractFromFeedTextSource()
        case .fetchText:
            return await extractFromFetchTextSource()
        case .extractText:
            return await extractFromWebViewSource()
        case .automatic:
            return false
        }
    }

    private func extractFromFeedTextSource() -> Bool {
        if let content = article.content, !content.isEmpty {
            let baseURL = URL(string: article.url)
            let text = HTMLContentExtractor.extractText(
                fromHTML: content, baseURL: baseURL, excludeTitle: article.title
            )
            result.text = text
            if let text, !text.isEmpty {
                persistCachedContent(text)
            }
        }
        return true
    }

    private func extractFromFetchTextSource() async -> Bool {
        guard let initialURL = URL(string: article.url) else { return true }
        let url = await HTMLContentExtractor.resolveOneCushionedURL(initialURL)
        let (html, _) = await fetchHTML(from: url)
        if let html {
            let extracted = HTMLContentExtractor.extractArticle(
                fromHTML: html, baseURL: url, excludeTitle: article.title
            )
            result.text = extracted.text
            if article.isEphemeral {
                mergeMetadata(extracted.metadata)
            }
            if let text = extracted.text, !text.isEmpty {
                persistCachedContent(text)
            }
        }
        return true
    }

    private func extractFromWebViewSource() async -> Bool {
        guard let initialURL = URL(string: article.url) else { return true }
        let url = await HTMLContentExtractor.resolveOneCushionedURL(initialURL)
        let text = await extractViaWebView(from: url, excludeTitle: article.title)
        result.text = text
        if let text, !text.isEmpty {
            persistCachedContent(text)
        }
        if article.isEphemeral, result.metadata.pageTitle == nil {
            let (html, _) = await fetchHTML(from: url)
            if let html {
                let extracted = HTMLContentExtractor.extractArticle(
                    fromHTML: html, baseURL: url, excludeTitle: article.title
                )
                mergeMetadata(extracted.metadata)
            }
        }
        return true
    }

    /// Tries the feed-supplied content as a last resort before web extraction.
    /// Skipped when the article came from Reddit (linked articles use the
    /// resolved URL, not Reddit's snippet), sits on a one-cushioned domain
    /// (LinkedIn etc., where the feed snippet is just a teaser), or has a
    /// registered `SiteContentExtractor` (which produces a richer extraction
    /// than the feed snippet, e.g. France24 chapo vs. full body).
    func tryFeedContentFallback() -> Bool {
        let articleURL = URL(string: article.url)
        let isOneCushionedArticle = articleURL.map(OneCushionedDomains.isOneCushioned) ?? false
        let hasSiteExtractor = articleURL.flatMap(SiteContentExtractorRegistry.extractor(for:)) != nil

        guard !isRedditLinkedArticle, !isOneCushionedArticle, !hasSiteExtractor,
              let content = article.content, !content.isEmpty else { return false }

        if HTMLContentExtractor.looksLikePartialFeedSnippet(content) {
            log("Extract", "Feed content looks partial (CTA link present), fetching full URL: \(article.url)")
            return false
        }

        let baseURL = URL(string: article.url)
        let text = HTMLContentExtractor.extractText(
            fromHTML: content, baseURL: baseURL, excludeTitle: article.title
        )
        if let text, !text.isEmpty {
            let paragraphCount = text.components(separatedBy: "\n\n").count
            let looksWellStructured = paragraphCount > 1 || text.count < 500
            // swiftlint:disable:next line_length
            log("Extract", "Feed content: \(paragraphCount) paragraphs, \(text.count) chars, wellStructured=\(looksWellStructured): \(article.url)")
            if looksWellStructured {
                result.text = text
                persistCachedContent(text)
                return true
            }
        }
        log("Extract", "Feed content unsuitable, falling through to URL fetch: \(article.url)")
        return false
    }
}
