import Foundation

public extension ContentResolver {

    /// Reads cached content unless the article is ephemeral.
    func readCachedContent() -> String? {
        guard !article.isEphemeral else { return nil }
        return try? DatabaseManager.shared.cachedArticleContent(for: article.id)
    }

    /// Persists extracted content unless the article is ephemeral
    /// (opened from `sakura://open`), in which case nothing is cached.
    func persistCachedContent(_ content: String) {
        guard !article.isEphemeral else { return }
        try? DatabaseManager.shared.cacheArticleContent(content, for: article.id)
    }

    /// Raw HTTP fetch returning decoded HTML and the response for header signals.
    func fetchHTML(from url: URL) async -> (String?, URLResponse?) {
        do {
            let request = URLRequest.sakura(url: url)
            let (data, response) = try await HTTPSPreferringSession.shared.data(for: request)
            return (HTMLDataDecoder.decode(data, response: response), response)
        } catch {
            return (nil, nil)
        }
    }

    func extractViaWebView(from url: URL, excludeTitle: String?) async -> String? {
        let extractor = WebViewExtractor()
        return await extractor.extractText(from: url)
    }

    /// Merges newly-extracted metadata into `result.metadata`, only filling
    /// fields that haven't already been set during the cascade. Lets later
    /// extraction phases (e.g. AMP fallback) backfill missing fields without
    /// clobbering values discovered earlier.
    func mergeMetadata(_ metadata: ArticleMetadata) {
        if result.metadata.author == nil, let author = metadata.author {
            result.metadata.author = author
        }
        if result.metadata.publishedDate == nil, let date = metadata.publishedDate {
            result.metadata.publishedDate = date
        }
        if result.metadata.leadImageURL == nil, let lead = metadata.leadImageURL {
            result.metadata.leadImageURL = lead
        }
        if let pageTitle = metadata.pageTitle {
            result.metadata.pageTitle = pageTitle
        }
    }

    static func isRedditPostURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased(),
              host == "reddit.com" || host.hasSuffix(".reddit.com") else { return false }
        return RedditProvider.postID(from: url) != nil
    }
}
