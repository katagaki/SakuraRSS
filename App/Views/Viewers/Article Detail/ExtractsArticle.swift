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
    fileprivate func persistCachedContent(_ content: String) {
        guard !article.isEphemeral else { return }
        try? DatabaseManager.shared.cacheArticleContent(content, for: article.id)
    }

    /// Fetches just the page title (`og:title` / `<title>`) for ephemeral
    /// articles so the URL placeholder is replaced quickly even when body
    /// extraction takes the JS-rendered or paywalled path.
    fileprivate func fetchEphemeralPageTitle(from url: URL) async {
        let (html, _) = await fetchHTML(from: url)
        guard let html, !html.isEmpty,
              let doc = try? SwiftSoup.parse(html),
              let pageTitle = ArticleExtractor.pageTitleFromDocument(doc) else { return }
        if extractedPageTitle == nil {
            extractedPageTitle = pageTitle
        }
    }

    /// Reads cached content unless the article is ephemeral.
    fileprivate func readCachedContent() -> String? {
        guard !article.isEphemeral else { return nil }
        return try? DatabaseManager.shared.cachedArticleContent(for: article.id)
    }

    fileprivate var articleSource: ArticleSource {
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

    // swiftlint:disable:next function_body_length cyclomatic_complexity
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

        log("Extract", "Source: \(source.rawValue), content length: \(article.content?.count ?? 0): \(article.url)")

        var contentURL: URL? = URL(string: article.url)
        var isRedditLinkedArticle = false

        let isRedditCandidate = feedManager.feed(forArticle: article)?.isRedditFeed == true
            || (article.isEphemeral && URL(string: article.url).map(Self.isRedditPostURL) == true)
        if isRedditCandidate {
            do {
                let result = try await RedditProvider.shared.fetchContent(for: article)
                switch result {
                case .markerString(let markerString):
                    if !markerString.isEmpty {
                        extractedText = markerString
                        persistCachedContent(markerString)
                        return
                    }
                case .linkedArticle(let linkedURL):
                    contentURL = linkedURL
                    isRedditLinkedArticle = true
                }
            } catch {
                log("Extract", "Reddit fetch failed, falling through: \(error)")
            }
        }

        let isHackerNewsCandidate = feedManager.feed(forArticle: article)?.isHackerNewsFeed == true
            || article.isEphemeral
        if isHackerNewsCandidate,
           let url = URL(string: article.url),
           HackerNewsPostFetcher.isSelfPostURL(url) {
            do {
                if let html = try await HackerNewsPostFetcher.fetchPostText(for: url) {
                    let text = ArticleExtractor.extractText(
                        fromHTML: html,
                        baseURL: url,
                        excludeTitle: articleTitle
                    )
                    if let text, !text.isEmpty {
                        extractedText = text
                        persistCachedContent(text)
                        return
                    }
                }
            } catch {
                log("Extract", "HN post fetch failed, falling through: \(error)")
            }
        }

        switch source {
        case .feedText:
            if let content = article.content, !content.isEmpty {
                let baseURL = URL(string: article.url)
                let text = ArticleExtractor.extractText(fromHTML: content,
                                                        baseURL: baseURL,
                                                        excludeTitle: articleTitle)
                extractedText = text
                if let text, !text.isEmpty {
                    persistCachedContent(text)
                }
            }
            return

        case .fetchText:
            if let initialURL = URL(string: article.url) {
                let url = await ArticleExtractor.resolveOneCushionedURL(initialURL)
                let (html, _) = await fetchHTML(from: url)
                if let html {
                    let text = ArticleExtractor.extractText(
                        fromHTML: html, baseURL: url, excludeTitle: articleTitle
                    )
                    extractedText = text
                    if article.isEphemeral {
                        let result = ArticleExtractor.extractArticle(
                            fromHTML: html, baseURL: url, excludeTitle: articleTitle
                        )
                        applyMetadata(result.metadata)
                    }
                    if let text, !text.isEmpty {
                        persistCachedContent(text)
                    }
                }
            }
            return

        case .extractText:
            if let initialURL = URL(string: article.url) {
                let url = await ArticleExtractor.resolveOneCushionedURL(initialURL)
                let text = await extractViaWebView(from: url, excludeTitle: articleTitle)
                extractedText = text
                if let text, !text.isEmpty {
                    persistCachedContent(text)
                }
                if article.isEphemeral, extractedPageTitle == nil {
                    let (html, _) = await fetchHTML(from: url)
                    if let html {
                        let result = ArticleExtractor.extractArticle(
                            fromHTML: html, baseURL: url, excludeTitle: articleTitle
                        )
                        applyMetadata(result.metadata)
                    }
                }
            }
            return

        case .automatic:
            break
        }

        if let url = URL(string: article.url), ArXivProvider.isAbstractURL(url) {
            if let summary = article.summary, !summary.isEmpty {
                extractedText = summary
                persistCachedContent(summary)
            }
            return
        }

        if article.isInstagramPostURL {
            let text = renderInstagramPostContent(article: article)
            extractedText = text
            if !text.isEmpty {
                persistCachedContent(text)
            }
            return
        }

        if article.isXPostURL,
           UserDefaults.standard.bool(forKey: "Labs.XProfileFeeds"),
           let url = URL(string: article.url),
           let tweetID = XProvider.extractTweetID(from: url),
           XProvider.hasSession() {
            let fetcher = XProvider()
            if let content = await fetcher.fetchTweetContent(tweetID: tweetID) {
                let text = renderXTweetContent(content)
                extractedText = text
                if extractedAuthor == nil {
                    let displayName = content.focal.author.isEmpty
                        ? "@\(content.focal.authorHandle)"
                        : content.focal.author
                    if !displayName.isEmpty {
                        extractedAuthor = displayName
                    }
                }
                if extractedPublishedDate == nil, let date = content.focal.publishedDate {
                    extractedPublishedDate = date
                }
                if !text.isEmpty {
                    persistCachedContent(text)
                }
                return
            }
            log("Extract", "X post fetch failed, falling through: \(article.url)")
        }

        if let url = URL(string: article.url), ExtractTextDomains.shouldExtractText(for: url) {
            let text = await extractViaWebView(from: url, excludeTitle: articleTitle)
            extractedText = text
            if let text, !text.isEmpty {
                persistCachedContent(text)
            }
            return
        }

        let isOneCushionedArticle: Bool = {
            guard let url = URL(string: article.url) else { return false }
            return OneCushionedDomains.isOneCushioned(url: url)
        }()

        if !isRedditLinkedArticle, !isOneCushionedArticle,
           let content = article.content, !content.isEmpty {
            let baseURL = URL(string: article.url)
            let text = ArticleExtractor.extractText(fromHTML: content,
                                                    baseURL: baseURL,
                                                    excludeTitle: articleTitle)
            if let text, !text.isEmpty {
                let paragraphCount = text.components(separatedBy: "\n\n").count
                let looksWellStructured = paragraphCount > 1 || text.count < 500
                // swiftlint:disable:next line_length
                log("Extract", "Feed content: \(paragraphCount) paragraphs, \(text.count) chars, wellStructured=\(looksWellStructured): \(article.url)")
                if looksWellStructured {
                    extractedText = text
                    persistCachedContent(text)
                    return
                }
            }
            log("Extract", "Feed content unsuitable, falling through to URL fetch: \(article.url)")
        }

        if let initialURL = contentURL.map(ArticleExtractor.unwrapGoogleAMPURL) {
            var url = initialURL
            var (rawHTML, response) = await fetchHTML(from: initialURL)

            if let html = rawHTML,
               let followURL = ArticleExtractor.oneCushionedArticleURL(
                fromHTML: html, baseURL: initialURL
               ) {
                url = followURL
                (rawHTML, response) = await fetchHTML(from: followURL)
            }

            var result: ExtractionResult
            let isChallenge = rawHTML.map(BotChallengeDetector.looksLikeChallenge) ?? false
            if isChallenge {
                let webText = await extractViaWebView(from: url, excludeTitle: articleTitle)
                result = ExtractionResult(text: webText)
            } else if let rawHTML {
                result = ArticleExtractor.extractArticle(
                    fromHTML: rawHTML,
                    baseURL: url,
                    excludeTitle: articleTitle
                )
                if !result.paywalled,
                   PaywallDetector.detect(response: response, extractedText: result.text) {
                    result.paywalled = true
                }
            } else {
                result = ExtractionResult()
            }

            let weak = ArticleExtractor.isWeakExtraction(result.text)
            let jsRendered = rawHTML.map(ArticleExtractor.looksJSRendered) ?? true

            if weak && !result.paywalled, let rawHTML,
               let ampURL = ArticleExtractor.amphtmlURL(from: rawHTML, baseURL: url) {
                let (ampHTML, ampResponse) = await fetchHTML(from: ampURL)
                if let ampHTML {
                    var ampResult = ArticleExtractor.extractArticle(
                        fromHTML: ampHTML,
                        baseURL: ampURL,
                        excludeTitle: articleTitle
                    )
                    if !ampResult.paywalled,
                       PaywallDetector.detect(response: ampResponse,
                                              extractedText: ampResult.text) {
                        ampResult.paywalled = true
                    }
                    if let ampText = ampResult.text,
                       !ArticleExtractor.isWeakExtraction(ampText) {
                        result.text = ampText
                        if result.metadata.author == nil {
                            result.metadata.author = ampResult.metadata.author
                        }
                        if result.metadata.publishedDate == nil {
                            result.metadata.publishedDate = ampResult.metadata.publishedDate
                        }
                        if result.metadata.leadImageURL == nil {
                            result.metadata.leadImageURL = ampResult.metadata.leadImageURL
                        }
                    }
                }
            }

            let stillWeak = ArticleExtractor.isWeakExtraction(result.text)
            if stillWeak && jsRendered && !result.paywalled {
                let webText = await extractViaWebView(
                    from: url, excludeTitle: articleTitle
                )
                if let webText, !webText.isEmpty,
                   !ArticleExtractor.isWeakExtraction(webText) || result.text == nil {
                    result.text = webText
                }
            }

            if !result.paywalled,
               let rawHTML,
               let text = result.text, !text.isEmpty,
               let extras = await ArticleExtractor.fetchPaginatedExtras(
                from: rawHTML, baseURL: url, excludeTitle: articleTitle
               ) {
                result.text = text + "\n\n" + extras
            }

            applyMetadata(result.metadata)
            isPaywalled = result.paywalled
            extractedText = result.text
            if !result.paywalled, let text = result.text, !text.isEmpty {
                persistCachedContent(text)
            }
        }
    }

    /// Applies extracted metadata without clobbering values already supplied by the feed.
    func applyMetadata(_ metadata: ArticleMetadata) {
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

    /// Raw HTTP fetch returning decoded HTML and the response for header signals.
    func fetchHTML(from url: URL) async -> (String?, URLResponse?) {
        do {
            let request = URLRequest.sakura(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            return (HTMLDataDecoder.decode(data, response: response), response)
        } catch {
            return (nil, nil)
        }
    }

    fileprivate func extractViaWebView(from url: URL, excludeTitle: String?) async -> String? {
        let extractor = WebViewExtractor()
        return await extractor.extractText(from: url)
    }

    static func isRedditPostURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased(),
              host == "reddit.com" || host.hasSuffix(".reddit.com") else { return false }
        return RedditProvider.postID(from: url) != nil
    }

    /// Builds the article body for an Instagram post: every carousel image
    /// stacked above the caption. Falls back to `article.imageURL` when the
    /// post is single-image (carousel array is empty in that case).
    func renderInstagramPostContent(article: Article) -> String {
        let imageURLs = !article.carouselImageURLs.isEmpty
            ? article.carouselImageURLs
            : (article.imageURL.map { [$0] } ?? [])

        var sections: [String] = imageURLs.map { "{{IMG}}\($0){{/IMG}}" }
        let caption = (article.summary ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !caption.isEmpty {
            sections.append(ArticleMarker.escape(caption))
        }
        return sections.joined(separator: "\n\n")
    }

    func renderXTweetContent(_ content: ParsedTweetContent) -> String {
        var sections: [String] = []
        for item in content.threadItems {
            var section = ArticleMarker.escape(item.text)
            for imageURL in item.imageURLs {
                section += "\n\n{{IMG}}\(imageURL){{/IMG}}"
            }
            if let quoted = item.quotedTweetURL {
                section += "\n\n{{XPOST}}\(quoted){{/XPOST}}"
            }
            sections.append(section)
        }
        return sections.joined(separator: "\n\n")
    }
}
