import Foundation

public extension ContentResolver {

    /// Last-resort path: full web fetch with paywall, bot-challenge, AMP,
    /// WebView, and paginated-extras handling (mirrors the article viewer).
    func performWebExtraction(initialURL: URL?) async {
        guard let unwrappedInitial = initialURL.map(HTMLContentExtractor.unwrapGoogleAMPURL) else { return }
        var url = unwrappedInitial
        var (rawHTML, response) = await fetchHTML(from: unwrappedInitial)

        if let html = rawHTML,
           let followURL = HTMLContentExtractor.oneCushionedArticleURL(
            fromHTML: html, baseURL: unwrappedInitial
           ) {
            url = followURL
            (rawHTML, response) = await fetchHTML(from: followURL)
        }

        var extraction = await initialExtractionResult(
            rawHTML: rawHTML, url: url, response: response
        )

        let jsRendered = rawHTML.map(HTMLContentExtractor.looksJSRendered) ?? true

        if HTMLContentExtractor.isWeakExtraction(extraction.text) && !extraction.paywalled, let rawHTML {
            await tryAMPExtraction(into: &extraction, rawHTML: rawHTML, url: url)
        }

        if HTMLContentExtractor.isWeakExtraction(extraction.text) && jsRendered && !extraction.paywalled {
            let webText = await extractViaWebView(from: url, excludeTitle: article.title)
            if let webText, !webText.isEmpty,
               !HTMLContentExtractor.isWeakExtraction(webText) || extraction.text == nil {
                extraction.text = webText
            }
        }

        if !extraction.paywalled, let rawHTML, let text = extraction.text, !text.isEmpty,
           let extras = await HTMLContentExtractor.fetchPaginatedExtras(
            from: rawHTML, baseURL: url, excludeTitle: article.title
           ) {
            extraction.text = text + "\n\n" + extras
        }

        mergeMetadata(extraction.metadata)
        result.paywalled = extraction.paywalled
        result.text = extraction.text
        if !extraction.paywalled, let text = extraction.text, !text.isEmpty {
            persistCachedContent(text)
        }
    }

    private func initialExtractionResult(
        rawHTML: String?, url: URL, response: URLResponse?
    ) async -> ExtractionResult {
        let isChallenge = rawHTML.map(BotChallengeDetector.looksLikeChallenge) ?? false
        if isChallenge {
            let webText = await extractViaWebView(from: url, excludeTitle: article.title)
            return ExtractionResult(text: webText)
        }
        if let rawHTML {
            var extracted = HTMLContentExtractor.extractArticle(
                fromHTML: rawHTML, baseURL: url, excludeTitle: article.title
            )
            if !extracted.paywalled,
               PaywallDetector.detect(response: response, extractedText: extracted.text) {
                extracted.paywalled = true
            }
            return extracted
        }
        return ExtractionResult()
    }

    private func tryAMPExtraction(
        into extraction: inout ExtractionResult, rawHTML: String, url: URL
    ) async {
        guard let ampURL = HTMLContentExtractor.amphtmlURL(from: rawHTML, baseURL: url) else { return }
        let (ampHTML, ampResponse) = await fetchHTML(from: ampURL)
        guard let ampHTML else { return }
        var ampResult = HTMLContentExtractor.extractArticle(
            fromHTML: ampHTML, baseURL: ampURL, excludeTitle: article.title
        )
        if !ampResult.paywalled,
           PaywallDetector.detect(response: ampResponse, extractedText: ampResult.text) {
            ampResult.paywalled = true
        }
        guard let ampText = ampResult.text,
              !HTMLContentExtractor.isWeakExtraction(ampText) else { return }
        extraction.text = ampText
        if extraction.metadata.author == nil {
            extraction.metadata.author = ampResult.metadata.author
        }
        if extraction.metadata.publishedDate == nil {
            extraction.metadata.publishedDate = ampResult.metadata.publishedDate
        }
        if extraction.metadata.leadImageURL == nil {
            extraction.metadata.leadImageURL = ampResult.metadata.leadImageURL
        }
    }
}
