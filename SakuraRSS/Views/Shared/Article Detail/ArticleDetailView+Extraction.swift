import SwiftUI

extension ArticleDetailView: ExtractsArticle {

    func refreshArticleContent() async {
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
        isExtracting = true

        if extractedText == nil, let previousText {
            let prevParagraphs = previousText.components(separatedBy: "\n\n").count
            if prevParagraphs > 1 || previousText.count < 500 {
                extractedText = previousText
                if !article.isEphemeral {
                    try? DatabaseManager.shared.cacheArticleContent(previousText, for: article.id)
                }
            }
        }
    }
}
