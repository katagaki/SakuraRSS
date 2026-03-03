import SwiftUI

extension ArticleDetailView {
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

        // For whitelisted domains, always fetch the full article via WKWebView
        if let url = URL(string: article.url), WebViewExtractor.requiresWebView(for: url) {
            let text = await ArticleExtractor.extractText(fromURL: url)
            extractedText = text
            if let text, !text.isEmpty {
                try? DatabaseManager.shared.cacheArticleContent(text, for: article.id)
            }
            return
        }

        if let content = article.content, !content.isEmpty {
            let text = ArticleExtractor.extractText(fromHTML: content)
            if let text, !text.isEmpty {
                extractedText = text
                try? DatabaseManager.shared.cacheArticleContent(text, for: article.id)
                return
            }
        }

        if let url = URL(string: article.url) {
            let text = await ArticleExtractor.extractText(fromURL: url)
            extractedText = text
            if let text, !text.isEmpty {
                try? DatabaseManager.shared.cacheArticleContent(text, for: article.id)
            }
        }
    }

    func refreshArticleContent() async {
        try? DatabaseManager.shared.clearCachedArticleContent(for: article.id)
        try? DatabaseManager.shared.clearCachedArticleSummary(for: article.id)
        translatedText = nil
        translatedTitle = nil
        summarizedText = nil
        hasCachedSummary = false
        showingSummary = false
        extractedText = nil
        await extractArticleContent()
    }

    func openArticleURL() {
        if article.isYouTubeURL {
            YouTubeHelper.openInApp(url: article.url)
        } else if let url = URL(string: article.url) {
            openURL(url)
        }
    }
}
