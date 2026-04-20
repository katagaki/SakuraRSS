import SwiftUI

extension ArticleDetailView {

    private var articleSource: ArticleSource {
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
        defer { isExtracting = false }

        #if DEBUG
        debugPrint("Extracting article content: \(article.url)")
        #endif

        if let cached = try? DatabaseManager.shared.cachedArticleContent(for: article.id),
           !cached.isEmpty {
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
                        try? DatabaseManager.shared.cacheArticleContent(
                            markerString, for: article.id
                        )
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
                    try? DatabaseManager.shared.cacheArticleContent(text, for: article.id)
                }
            }
            return

        case .fetchText:
            if let initialURL = URL(string: article.url) {
                let url = await ArticleExtractor.resolveOneCushionedURL(initialURL)
                let text = await fetchText(from: url, excludeTitle: articleTitle)
                extractedText = text
                if let text, !text.isEmpty {
                    try? DatabaseManager.shared.cacheArticleContent(text, for: article.id)
                }
            }
            return

        case .extractText:
            if let initialURL = URL(string: article.url) {
                let url = await ArticleExtractor.resolveOneCushionedURL(initialURL)
                let text = await extractViaWebView(from: url, excludeTitle: articleTitle)
                extractedText = text
                if let text, !text.isEmpty {
                    try? DatabaseManager.shared.cacheArticleContent(text, for: article.id)
                }
            }
            return

        case .automatic:
            break
        }

        // Automatic: use domain lists to determine the best extraction method

        // For arXiv abstract pages, the RSS feed already contains the paper's
        // abstract, and the arxiv.org abstract page itself is mostly metadata
        // we don't want to render. Prefer the feed summary directly.
        if let url = URL(string: article.url), ArXivHelper.isArXivAbstractURL(url) {
            if let summary = article.summary, !summary.isEmpty {
                extractedText = summary
                try? DatabaseManager.shared.cacheArticleContent(summary, for: article.id)
            }
            return
        }

        // For X post URLs (from non-X feeds), use the X API to fetch the tweet directly
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
                    try? DatabaseManager.shared.cacheArticleContent(text, for: article.id)
                }
                return
            }
            // If X API fetch failed, fall through to normal extraction
            #if DEBUG
            debugPrint("[Extract] X post fetch failed, falling through: \(article.url)")
            #endif
        }

        // For ExtractText domains (e.g. apple.com), use WebView-based extraction
        if let url = URL(string: article.url), ExtractTextDomains.shouldExtractText(for: url) {
            let text = await extractViaWebView(from: url, excludeTitle: articleTitle)
            extractedText = text
            if let text, !text.isEmpty {
                try? DatabaseManager.shared.cacheArticleContent(text, for: article.id)
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
                // If a long text has very few paragraphs, the feed content likely
                // lacks proper HTML structure. Fall through to URL fetch for a
                // better extraction with the original page's <p> tags.
                let looksWellStructured = paragraphCount > 1 || text.count < 500
                #if DEBUG
                debugPrint("[Extract] Feed content: \(paragraphCount) paragraphs, \(text.count) chars, wellStructured=\(looksWellStructured): \(article.url)")
                #endif
                if looksWellStructured {
                    extractedText = text
                    try? DatabaseManager.shared.cacheArticleContent(text, for: article.id)
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

            // Auto-escalate when the plain HTTP extraction is too thin AND
            // the HTML looks JS-rendered — Substack, React/Next.js, etc.
            let weak = ArticleExtractor.isWeakExtraction(result.text)
            let jsRendered = rawHTML.map(ArticleExtractor.looksJSRendered) ?? true

            // Retry against the AMP variant of the page when the canonical
            // response was too short.  AMP markup extracts more reliably
            // than generic JS-rendered pages.
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
                try? DatabaseManager.shared.cacheArticleContent(text, for: article.id)
            }
        }
    }

    /// Applies extracted metadata to `@State` fields without clobbering
    /// values already supplied by the feed.
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
    }

    /// Raw HTTP fetch used by the automatic extraction path.  Returns the
    /// decoded HTML string alongside the URL response for header-based
    /// signals (paywall status codes, encoding detection, …).
    func fetchHTML(from url: URL) async -> (String?, URLResponse?) {
        do {
            let request = URLRequest.sakura(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            return (HTMLDataDecoder.decode(data, response: response), response)
        } catch {
            return (nil, nil)
        }
    }

    /// Simple GET + HTML parse (no JavaScript rendering).
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

    /// WebView-based extraction (loads page with JavaScript like Apple Newsroom).
    private func extractViaWebView(from url: URL, excludeTitle: String?) async -> String? {
        let extractor = WebViewExtractor()
        return await extractor.extractText(from: url)
    }

    func refreshArticleContent() async {
        // Show spinner immediately to avoid flashing article.summary
        // while extraction is pending
        isExtracting = true
        defer { isExtracting = false }

        // Clear cached images for this article
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

        // Keep the previous text so we can fall back if re-extraction fails
        let previousText = extractedText
        extractedText = nil
        await extractArticleContent()
        // `extractArticleContent` flips `isExtracting` off via its own defer
        // before returning. Re-assert it so the spinner stays visible while
        // the fallback restoration below runs, avoiding a brief render with
        // `article.summary` when the new extraction produced nothing.
        isExtracting = true

        // If re-extraction produced nothing, restore the previous content
        // and re-cache it so subsequent loads still work.
        // Only restore if the previous content was well-structured;
        // don't re-cache a wall of text with no paragraph breaks.
        if extractedText == nil, let previousText {
            let prevParagraphs = previousText.components(separatedBy: "\n\n").count
            if prevParagraphs > 1 || previousText.count < 500 {
                extractedText = previousText
                try? DatabaseManager.shared.cacheArticleContent(previousText, for: article.id)
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
