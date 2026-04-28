import SwiftUI
import SwiftSoup

extension ArticleDetailView {

    /// Persists extracted content unless the article is ephemeral (opened
    /// from `sakura://open`), in which case nothing is cached.
    private func persistCachedContent(_ content: String) {
        guard !article.isEphemeral else { return }
        try? DatabaseManager.shared.cacheArticleContent(content, for: article.id)
    }

    /// Fetches just the page title (`og:title` / `<title>`) for ephemeral
    /// articles so the URL placeholder is replaced quickly even when body
    /// extraction takes the JS-rendered or paywalled path.
    private func fetchEphemeralPageTitle(from url: URL) async {
        let (html, _) = await fetchHTML(from: url)
        guard let html, !html.isEmpty,
              let doc = try? SwiftSoup.parse(html),
              let pageTitle = ArticleExtractor.pageTitleFromDocument(doc) else { return }
        if extractedPageTitle == nil {
            extractedPageTitle = pageTitle
        }
    }

    /// Reads cached content unless the article is ephemeral.
    private func readCachedContent() -> String? {
        guard !article.isEphemeral else { return nil }
        return try? DatabaseManager.shared.cachedArticleContent(for: article.id)
    }

    private var articleSource: ArticleSource {
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

        // Resolve the page title eagerly for ephemeral articles so it shows
        // even when the body extraction takes the JS-rendered or paywalled
        // path that skips metadata extraction.
        if article.isEphemeral, let url = URL(string: article.url) {
            Task { @MainActor in
                await fetchEphemeralPageTitle(from: url)
            }
        }

        #if DEBUG
        debugPrint("Extracting article content: \(article.url)")
        #endif

        if let cached = readCachedContent(), !cached.isEmpty {
            extractedText = cached
            #if DEBUG
            debugPrint("[Extract] Cache hit (\(cached.count) chars): \(article.url)")
            #endif
            return
        }

        #if DEBUG
        debugPrint("[Extract] Cache miss: \(article.url)")
        #endif

        let articleTitle = article.title
        let source = articleSource

        #if DEBUG
        debugPrint("[Extract] Source: \(source.rawValue), content length: \(article.content?.count ?? 0): \(article.url)")
        #endif

        var contentURL: URL? = URL(string: article.url)
        var isRedditLinkedArticle = false

        if feedManager.feed(forArticle: article)?.isRedditFeed == true {
            do {
                let result = try await RedditPostScraper.shared.fetchContent(for: article)
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
                #if DEBUG
                debugPrint("[Extract] Reddit fetch failed, falling through: \(error)")
                #endif
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

        // arxiv.org abstract pages are mostly metadata; prefer the feed summary directly.
        if let url = URL(string: article.url), ArXivHelper.isArXivAbstractURL(url) {
            if let summary = article.summary, !summary.isEmpty {
                extractedText = summary
                persistCachedContent(summary)
            }
            return
        }

        let isFromXFeed = feedManager.feed(forArticle: article)?.isXFeed == true
        if article.isXPostURL, !isFromXFeed,
           UserDefaults.standard.bool(forKey: "Labs.XProfileFeeds"),
           let url = URL(string: article.url),
           let tweetID = XProfileScraper.extractTweetID(from: url),
           await XProfileScraper.hasXSession() {
            let scraper = XProfileScraper()
            if let tweet = await scraper.fetchSingleTweet(tweetID: tweetID) {
                var text = ArticleMarker.escape(tweet.text)
                if let imageURL = tweet.imageURL {
                    text += "\n\n{{IMG}}\(imageURL){{/IMG}}"
                }
                extractedText = text
                if !text.isEmpty {
                    persistCachedContent(text)
                }
                return
            }
            #if DEBUG
            debugPrint("[Extract] X post fetch failed, falling through: \(article.url)")
            #endif
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
                // If long text has very few paragraphs, feed HTML is likely malformed; fall through.
                let looksWellStructured = paragraphCount > 1 || text.count < 500
                #if DEBUG
                debugPrint("[Extract] Feed content: \(paragraphCount) paragraphs, \(text.count) chars, wellStructured=\(looksWellStructured): \(article.url)")
                #endif
                if looksWellStructured {
                    extractedText = text
                    persistCachedContent(text)
                    return
                }
            }
            #if DEBUG
            debugPrint("[Extract] Feed content unsuitable, falling through to URL fetch: \(article.url)")
            #endif
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

            // AMP markup extracts more reliably than generic JS-rendered pages.
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

    private func fetchText(from url: URL, excludeTitle: String?) async -> String? {
        do {
            let (data, response) = try await URLSession.shared.data(
                for: URLRequest.sakura(url: url)
            )
            guard let html = HTMLDataDecoder.decode(data, response: response) else { return nil }
            return ArticleExtractor.extractText(fromHTML: html, baseURL: url, excludeTitle: excludeTitle)
        } catch {
            return nil
        }
    }

    private func extractViaWebView(from url: URL, excludeTitle: String?) async -> String? {
        let extractor = WebViewExtractor()
        return await extractor.extractText(from: url)
    }

    func refreshArticleContent() async {
        // Show spinner immediately to avoid flashing article.summary while extraction is pending.
        isExtracting = true
        defer { isExtracting = false }

        if let imageURL = article.imageURL {
            try? DatabaseManager.shared.clearCachedImageData(for: imageURL)
        }
        if let text = extractedText {
            let pattern = #"\{\{IMG\}\}(.+?)\{\{/IMG\}\}"#
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let nsText = text as NSString
                let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
                for match in matches {
                    let url = nsText.substring(with: match.range(at: 1))
                    try? DatabaseManager.shared.clearCachedImageData(for: url)
                }
            }
        }

        try? DatabaseManager.shared.clearCachedArticleContent(for: article.id)
        try? DatabaseManager.shared.clearCachedArticleSummary(for: article.id)
        try? DatabaseManager.shared.clearCachedArticleTranslation(for: article.id)
        translatedText = nil
        translatedTitle = nil
        translatedSummary = nil
        showingTranslation = false
        hasCachedTranslation = false
        summarizedText = nil
        hasCachedSummary = false
        showingSummary = false

        let previousText = extractedText
        extractedText = nil
        await extractArticleContent()
        // Re-assert over `extractArticleContent`'s `defer` so spinner stays visible through fallback.
        isExtracting = true

        // Only restore previous content if it was well-structured.
        if extractedText == nil, let previousText {
            let prevParagraphs = previousText.components(separatedBy: "\n\n").count
            if prevParagraphs > 1 || previousText.count < 500 {
                extractedText = previousText
                persistCachedContent(previousText)
            }
        }
    }

    func openArticleURL() {
        if article.isYouTubeURL && youTubeOpenMode == .inAppPlayer {
            showYouTubePlayer = true
        } else if article.isYouTubeURL && youTubeOpenMode == .youTubeApp {
            YouTubeHelper.openInApp(url: article.url)
        } else if article.isYouTubeURL && youTubeOpenMode == .browser {
            showYouTubeSafari = true
        } else if let url = URL(string: article.url) {
            openURL(url)
        }
    }
}
