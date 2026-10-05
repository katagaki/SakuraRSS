import Foundation

public extension ContentResolver {

    /// Runs the full extraction cascade and returns the accumulated
    /// `ExtractionResult`. Order: cache → Reddit → HackerNews → user-set
    /// source mode → provider-specific (ArXiv/Instagram/X/extract-text
    /// domains) → feed-content fallback (with quality gate) → full web
    /// extraction. Caching is handled internally; ephemeral articles
    /// (`sakura://open` opens) are never cached.
    public func extract() async -> ExtractionResult {
        await runExtractionCascade()
        if let text = result.text, !text.isEmpty {
            result.challenged = false
        }
        return result
    }

    private func runExtractionCascade() async {
        log("Extract", "Extracting article content: \(article.url)")

        if let cached = readCachedContent(), !cached.isEmpty {
            result.text = cached
            log("Extract", "Cache hit (\(cached.count) chars): \(article.url)")
            return
        }

        log("Extract", "Cache miss: \(article.url)")

        let source = articleSource
        let contentLength = article.content?.count ?? 0
        log("Extract", "Source: \(source.rawValue), content length: \(contentLength): \(article.url)")

        switch await tryRedditExtraction() {
        case .handled:
            return
        case .linkedArticle(let linkedURL):
            contentURL = linkedURL
            isRedditLinkedArticle = true
        case .none:
            break
        }

        if await tryHackerNewsExtraction() { return }
        if await extractFromSpecificSource(source) { return }
        if await tryProviderExtraction() { return }
        if tryFeedContentFallback() { return }

        if article.isXPostURL {
            log("Extract", "Skipping web extraction for X post, x.com requires JavaScript: \(article.url)")
            return
        }

        await performWebExtraction(initialURL: contentURL)
    }
}
