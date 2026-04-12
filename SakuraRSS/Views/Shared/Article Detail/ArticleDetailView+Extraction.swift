import SwiftUI

extension ArticleDetailView {

    private var articleSource: ArticleSource {
        let raw = UserDefaults.standard.string(forKey: "articleSource-\(article.feedID)")
        return raw.flatMap(ArticleSource.init(rawValue:)) ?? .automatic
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func extractArticleContent() async {
        isExtracting = true
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
            if let url = URL(string: article.url) {
                let text = await fetchText(from: url, excludeTitle: articleTitle)
                extractedText = text
                if let text, !text.isEmpty {
                    try? DatabaseManager.shared.cacheArticleContent(text, for: article.id)
                }
            }
            return

        case .extractText:
            if let url = URL(string: article.url) {
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

        // For X post URLs (from non-X feeds), use the X API to fetch the tweet directly
        let isFromXFeed = feedManager.feed(forArticle: article)?.isXFeed == true
        if article.isXPostURL, !isFromXFeed,
           UserDefaults.standard.bool(forKey: "Labs.XProfileFeeds"),
           let url = URL(string: article.url),
           let tweetID = XURLHelpers.extractTweetID(from: url),
           await XIntegration.hasSession() {
            let integration = XIntegration()
            if let tweet = await integration.fetchSingleTweet(tweetID: tweetID) {
                var text = tweet.text
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

        if let content = article.content, !content.isEmpty {
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

        if let url = URL(string: article.url) {
            var text = await ArticleExtractor.extractText(fromURL: url,
                                                          excludeTitle: articleTitle)
            #if DEBUG
            if let text {
                let paragraphCount = text.components(separatedBy: "\n\n").count
                debugPrint("[Extract] Using URL fetch (\(paragraphCount) paragraphs, \(text.count) chars): \(article.url)")
            } else {
                debugPrint("[Extract] URL fetch returned nil, trying WebView: \(article.url)")
            }
            #endif

            // If plain HTTP fetch failed (e.g. JS-rendered site), try WebView extraction.
            if text == nil {
                text = await extractViaWebView(from: url, excludeTitle: articleTitle)
                #if DEBUG
                if let text {
                    let paragraphCount = text.components(separatedBy: "\n\n").count
                    debugPrint("[Extract] WebView fallback produced (\(paragraphCount) paragraphs, \(text.count) chars): \(url)")
                } else {
                    debugPrint("[Extract] WebView fallback also returned nil: \(url)")
                }
                #endif
            }

            extractedText = text
            if let text, !text.isEmpty {
                try? DatabaseManager.shared.cacheArticleContent(text, for: article.id)
            }
        }
    }

    /// Simple GET + HTML parse (no JavaScript rendering).
    private func fetchText(from url: URL, excludeTitle: String?) async -> String? {
        do {
            var request = URLRequest(url: url)
            request.setValue(
                sakuraUserAgent,
                forHTTPHeaderField: "User-Agent"
            )
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else { return nil }
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
