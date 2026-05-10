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

    /// Fetches just the page title (`og:title` / `<title>`) for ephemeral
    /// articles so the URL placeholder is replaced quickly even when body
    /// extraction takes the JS-rendered or paywalled path.
    func fetchEphemeralPageTitle(from url: URL) async {
        let request = URLRequest.sakura(url: url)
        guard let (data, response) = try? await HTTPSPreferringSession.shared.data(for: request),
              let html = HTMLDataDecoder.decode(data, response: response),
              !html.isEmpty,
              let doc = try? SwiftSoup.parse(html),
              let pageTitle = ArticleExtractor.pageTitleFromDocument(doc) else { return }
        if extractedPageTitle == nil {
            extractedPageTitle = pageTitle
        }
    }

    /// Drives the shared `ArticleContentExtractor` and surfaces its result
    /// onto the view's bindings. Side-effects (caching, feed-source
    /// preference, provider routing) all live in the extractor.
    func extractArticleContent() async {
        isExtracting = true
        isPaywalled = false
        defer { isExtracting = false }
        // Keep previously-extracted metadata in place; `applyExtractedMetadata`
        // only writes when the new run produces a value, so a transient fetch
        // failure on pull-to-refresh doesn't blank the lead image / byline.

        if article.isEphemeral, let url = URL(string: article.url) {
            Task { @MainActor in
                await fetchEphemeralPageTitle(from: url)
            }
        }

        let extractor = ArticleContentExtractor(
            article: article,
            feed: feedManager.feed(forArticle: article),
            articleSourceOverride: ephemeralTextMode.map(ArticleSource.init(textMode:))
        )
        let extracted = await extractor.extract()

        applyExtractedMetadata(extracted.metadata)
        isPaywalled = extracted.paywalled
        extractedText = extracted.text
    }

    /// Writes extracted metadata to view bindings, leaving feed-supplied
    /// fields alone so the UI continues to favor the original byline /
    /// timestamp / hero image when they exist.
    private func applyExtractedMetadata(_ metadata: ArticleMetadata) {
        if article.author == nil, let author = metadata.author {
            extractedAuthor = author
        }
        if article.publishedDate == nil, let date = metadata.publishedDate {
            extractedPublishedDate = date
        }
        if article.imageURL == nil, let lead = metadata.leadImageURL {
            extractedLeadImageURL = lead
        }
        if let pageTitle = metadata.pageTitle {
            extractedPageTitle = pageTitle
        }
    }
}

extension ArticleSource {
    /// Translates the `sakura://open` text-mode override into the same
    /// `ArticleSource` enum used by the per-feed UserDefaults setting.
    init(textMode: OpenArticleRequest.TextMode) {
        switch textMode {
        case .auto: self = .automatic
        case .fetch: self = .fetchText
        case .extract: self = .extractText
        }
    }
}
