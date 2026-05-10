import Foundation

public extension ContentResolver {

    /// Runs the full extraction cascade and returns the accumulated
    /// `ExtractionResult`. Order: cache → Reddit → HackerNews → user-set
    /// source mode → provider-specific (ArXiv/Instagram/X/extract-text
    /// domains) → feed-content fallback (with quality gate) → full web
    /// extraction. Caching is handled internally; ephemeral articles
    /// (`sakura://open` opens) are never cached.
    func extract() async -> ExtractionResult {
        log("Extract", "Extracting article content: \(article.url)")

        if let cached = readCachedContent(), !cached.isEmpty {
            result.text = cached
            log("Extract", "Cache hit (\(cached.count) chars): \(article.url)")
            return result
        }

        log("Extract", "Cache miss: \(article.url)")

        let source = articleSource
        let contentLength = article.content?.count ?? 0
        log("Extract", "Source: \(source.rawValue), content length: \(contentLength): \(article.url)")

        switch await tryRedditExtraction() {
        case .handled:
            return result
        case .linkedArticle(let linkedURL):
            contentURL = linkedURL
            isRedditLinkedArticle = true
        case .none:
            break
        }

        if await tryHackerNewsExtraction() { return result }
        if await extractFromSpecificSource(source) { return result }
        if await tryProviderExtraction() { return result }
        if tryFeedContentFallback() { return result }

        await performWebExtraction(initialURL: contentURL)
        return result
    }
}
