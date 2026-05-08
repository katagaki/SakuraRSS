import Foundation

enum RedditExtractionOutcome {
    case handled
    case linkedArticle(URL)
    case none
}

extension ExtractsArticle {

    func tryRedditExtraction() async -> RedditExtractionOutcome {
        let isRedditCandidate = feedManager.feed(forArticle: article)?.isRedditFeed == true
            || (article.isEphemeral && URL(string: article.url).map { Self.isRedditPostURL($0) } == true)
        guard isRedditCandidate else { return .none }
        do {
            let result = try await RedditProvider.shared.fetchContent(for: article)
            switch result {
            case .markerString(let markerString):
                if !markerString.isEmpty {
                    extractedText = markerString
                    persistCachedContent(markerString)
                    return .handled
                }
                return .none
            case .linkedArticle(let linkedURL):
                return .linkedArticle(linkedURL)
            }
        } catch {
            log("Extract", "Reddit fetch failed, falling through: \(error)")
            return .none
        }
    }

    func tryHackerNewsExtraction(articleTitle: String) async -> Bool {
        let isHackerNewsCandidate = feedManager.feed(forArticle: article)?.isHackerNewsFeed == true
            || article.isEphemeral
        guard isHackerNewsCandidate,
              let url = URL(string: article.url),
              HackerNewsPostFetcher.isSelfPostURL(url) else { return false }
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
                    return true
                }
            }
        } catch {
            log("Extract", "HN post fetch failed, falling through: \(error)")
        }
        return false
    }

    func extractFromSpecificSource(_ source: ArticleSource, articleTitle: String) async -> Bool {
        switch source {
        case .feedText:
            return extractFromFeedTextSource(articleTitle: articleTitle)
        case .fetchText:
            return await extractFromFetchTextSource(articleTitle: articleTitle)
        case .extractText:
            return await extractFromWebViewSource(articleTitle: articleTitle)
        case .automatic:
            return false
        }
    }

    private func extractFromFeedTextSource(articleTitle: String) -> Bool {
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
        return true
    }

    private func extractFromFetchTextSource(articleTitle: String) async -> Bool {
        guard let initialURL = URL(string: article.url) else { return true }
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
        return true
    }

    private func extractFromWebViewSource(articleTitle: String) async -> Bool {
        guard let initialURL = URL(string: article.url) else { return true }
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
        return true
    }

    func tryProviderExtraction(articleTitle: String) async -> Bool {
        if tryArXivExtraction() { return true }
        if tryInstagramExtraction() { return true }
        if await tryXPostExtraction() { return true }
        return await tryExtractTextDomain(articleTitle: articleTitle)
    }

    private func tryArXivExtraction() -> Bool {
        guard let url = URL(string: article.url), ArXivProvider.isAbstractURL(url) else { return false }
        if let summary = article.summary, !summary.isEmpty {
            extractedText = summary
            persistCachedContent(summary)
        }
        return true
    }

    private func tryInstagramExtraction() -> Bool {
        guard article.isInstagramPostURL else { return false }
        let text = renderInstagramPostContent(article: article)
        extractedText = text
        if !text.isEmpty {
            persistCachedContent(text)
        }
        return true
    }

    private func tryXPostExtraction() async -> Bool {
        guard article.isXPostURL,
              UserDefaults.standard.bool(forKey: "Labs.XProfileFeeds"),
              let url = URL(string: article.url),
              let tweetID = XProvider.extractTweetID(from: url),
              XProvider.hasSession() else { return false }
        let fetcher = XProvider()
        if let content = await fetcher.fetchTweetContent(tweetID: tweetID) {
            applyXTweetContent(content)
            return true
        }
        log("Extract", "X post fetch failed, falling through: \(article.url)")
        return false
    }

    private func applyXTweetContent(_ content: ParsedTweetContent) {
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
    }

    private func tryExtractTextDomain(articleTitle: String) async -> Bool {
        guard let url = URL(string: article.url),
              ExtractTextDomains.shouldExtractText(for: url) else { return false }
        let text = await extractViaWebView(from: url, excludeTitle: articleTitle)
        extractedText = text
        if let text, !text.isEmpty {
            persistCachedContent(text)
        }
        return true
    }

    func tryFeedContentFallback(articleTitle: String, isRedditLinkedArticle: Bool) -> Bool {
        let isOneCushionedArticle: Bool = {
            guard let url = URL(string: article.url) else { return false }
            return OneCushionedDomains.isOneCushioned(url: url)
        }()

        guard !isRedditLinkedArticle, !isOneCushionedArticle,
              let content = article.content, !content.isEmpty else { return false }

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
                return true
            }
        }
        log("Extract", "Feed content unsuitable, falling through to URL fetch: \(article.url)")
        return false
    }

    func performWebExtraction(initialURL: URL?, articleTitle: String) async {
        guard let unwrappedInitial = initialURL.map(ArticleExtractor.unwrapGoogleAMPURL) else { return }
        var url = unwrappedInitial
        var (rawHTML, response) = await fetchHTML(from: unwrappedInitial)

        if let html = rawHTML,
           let followURL = ArticleExtractor.oneCushionedArticleURL(
            fromHTML: html, baseURL: unwrappedInitial
           ) {
            url = followURL
            (rawHTML, response) = await fetchHTML(from: followURL)
        }

        var result = await initialExtractionResult(
            rawHTML: rawHTML, url: url, response: response, articleTitle: articleTitle
        )

        let jsRendered = rawHTML.map(ArticleExtractor.looksJSRendered) ?? true

        if ArticleExtractor.isWeakExtraction(result.text) && !result.paywalled, let rawHTML {
            await tryAMPExtraction(
                into: &result, rawHTML: rawHTML, url: url, articleTitle: articleTitle
            )
        }

        if ArticleExtractor.isWeakExtraction(result.text) && jsRendered && !result.paywalled {
            let webText = await extractViaWebView(from: url, excludeTitle: articleTitle)
            if let webText, !webText.isEmpty,
               !ArticleExtractor.isWeakExtraction(webText) || result.text == nil {
                result.text = webText
            }
        }

        if !result.paywalled, let rawHTML, let text = result.text, !text.isEmpty,
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

    private func initialExtractionResult(
        rawHTML: String?, url: URL, response: URLResponse?, articleTitle: String
    ) async -> ExtractionResult {
        let isChallenge = rawHTML.map(BotChallengeDetector.looksLikeChallenge) ?? false
        if isChallenge {
            let webText = await extractViaWebView(from: url, excludeTitle: articleTitle)
            return ExtractionResult(text: webText)
        }
        if let rawHTML {
            var result = ArticleExtractor.extractArticle(
                fromHTML: rawHTML, baseURL: url, excludeTitle: articleTitle
            )
            if !result.paywalled,
               PaywallDetector.detect(response: response, extractedText: result.text) {
                result.paywalled = true
            }
            return result
        }
        return ExtractionResult()
    }

    private func tryAMPExtraction(
        into result: inout ExtractionResult, rawHTML: String, url: URL, articleTitle: String
    ) async {
        guard let ampURL = ArticleExtractor.amphtmlURL(from: rawHTML, baseURL: url) else { return }
        let (ampHTML, ampResponse) = await fetchHTML(from: ampURL)
        guard let ampHTML else { return }
        var ampResult = ArticleExtractor.extractArticle(
            fromHTML: ampHTML, baseURL: ampURL, excludeTitle: articleTitle
        )
        if !ampResult.paywalled,
           PaywallDetector.detect(response: ampResponse, extractedText: ampResult.text) {
            ampResult.paywalled = true
        }
        guard let ampText = ampResult.text,
              !ArticleExtractor.isWeakExtraction(ampText) else { return }
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
