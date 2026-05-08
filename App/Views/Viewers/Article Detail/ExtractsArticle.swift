import SwiftUI
import SwiftSoup

@MainActor
protocol ExtractsArticle {
    var article: Article { get }
    var feedManager: FeedManager { get }
    var ephemeralTextMode: OpenArticleRequest.TextMode? { get }

    var extractedText: String? { get nonmutating set }
    var isExtracting: Bool { get nonmutating set }
    var isPaywalled: Bool { get nonmutating set }
    var extractedAuthor: String? { get nonmutating set }
    var extractedPublishedDate: Date? { get nonmutating set }
    var extractedLeadImageURL: String? { get nonmutating set }
    var extractedPageTitle: String? { get nonmutating set }
}

extension ExtractsArticle {

    var ephemeralTextMode: OpenArticleRequest.TextMode? { nil }

    /// Persists extracted content unless the article is ephemeral (opened
    /// from `sakura://open`), in which case nothing is cached.
    func persistCachedContent(_ content: String) {
        guard !article.isEphemeral else { return }
        try? DatabaseManager.shared.cacheArticleContent(content, for: article.id)
    }

    /// Fetches just the page title (`og:title` / `<title>`) for ephemeral
    /// articles so the URL placeholder is replaced quickly even when body
    /// extraction takes the JS-rendered or paywalled path.
    func fetchEphemeralPageTitle(from url: URL) async {
        let (html, _) = await fetchHTML(from: url)
        guard let html, !html.isEmpty,
              let doc = try? SwiftSoup.parse(html),
              let pageTitle = ArticleExtractor.pageTitleFromDocument(doc) else { return }
        if extractedPageTitle == nil {
            extractedPageTitle = pageTitle
        }
    }

    /// Reads cached content unless the article is ephemeral.
    func readCachedContent() -> String? {
        guard !article.isEphemeral else { return nil }
        return try? DatabaseManager.shared.cachedArticleContent(for: article.id)
    }

    var articleSource: ArticleSource {
        if let ephemeralTextMode {
            switch ephemeralTextMode {
            case .auto: return .automatic
            case .fetch: return .fetchText
            case .extract: return .extractText
            }
        }
        let raw = UserDefaults.standard.string(forKey: "articleSource-\(article.feedID)")
        return raw.flatMap(ArticleSource.init(rawValue:)) ?? .automatic
    }

    func extractArticleContent() async {
        isExtracting = true
        isPaywalled = false
        extractedAuthor = nil
        extractedPublishedDate = nil
        extractedLeadImageURL = nil
        extractedPageTitle = nil
        defer { isExtracting = false }

        if article.isEphemeral, let url = URL(string: article.url) {
            Task { @MainActor in
                await fetchEphemeralPageTitle(from: url)
            }
        }

        log("Extract", "Extracting article content: \(article.url)")

        if let cached = readCachedContent(), !cached.isEmpty {
            extractedText = cached
            log("Extract", "Cache hit (\(cached.count) chars): \(article.url)")
            return
        }

        log("Extract", "Cache miss: \(article.url)")

        let articleTitle = article.title
        let source = articleSource
        let contentLength = article.content?.count ?? 0
        log("Extract", "Source: \(source.rawValue), content length: \(contentLength): \(article.url)")

        var contentURL: URL? = URL(string: article.url)
        var isRedditLinkedArticle = false

        switch await tryRedditExtraction() {
        case .handled:
            return
        case .linkedArticle(let linkedURL):
            contentURL = linkedURL
            isRedditLinkedArticle = true
        case .none:
            break
        }

        if await tryHackerNewsExtraction(articleTitle: articleTitle) { return }
        if await extractFromSpecificSource(source, articleTitle: articleTitle) { return }
        if await tryProviderExtraction(articleTitle: articleTitle) { return }
        if tryFeedContentFallback(articleTitle: articleTitle,
                                  isRedditLinkedArticle: isRedditLinkedArticle) { return }

        await performWebExtraction(initialURL: contentURL, articleTitle: articleTitle)
    }

}
