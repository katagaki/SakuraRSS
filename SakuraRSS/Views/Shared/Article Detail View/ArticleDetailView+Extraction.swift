import SwiftUI

extension ArticleDetailView {

    private var articleSource: ArticleSource {
        let raw = UserDefaults.standard.string(forKey: "articleSource-\(article.feedID)")
        return raw.flatMap(ArticleSource.init(rawValue:)) ?? .automatic
    }

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
            debugPrint("Using cached content: \(article.url)")
            #endif
            return
        }

        let articleTitle = article.title
        let source = articleSource

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
                extractedText = text
                try? DatabaseManager.shared.cacheArticleContent(text, for: article.id)
                return
            }
        }

        if let url = URL(string: article.url) {
            let text = await ArticleExtractor.extractText(fromURL: url,
                                                          excludeTitle: articleTitle)
            extractedText = text
            if let text, !text.isEmpty {
                try? DatabaseManager.shared.cacheArticleContent(text, for: article.id)
            }
        }
    }

    /// Simple GET + HTML parse (no JavaScript rendering).
    private func fetchText(from url: URL, excludeTitle: String?) async -> String? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
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
        extractedText = nil
        await extractArticleContent()
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
