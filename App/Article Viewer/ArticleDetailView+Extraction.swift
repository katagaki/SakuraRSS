import SwiftUI
import Hanami

extension ArticleDetailView: ExtractsArticle {

    func refreshArticleContent() async {
        isExtracting = true
        defer { isExtracting = false }

        let articleID = article.id
        var imageURLs: [String] = []
        if let imageURL = article.imageURL {
            imageURLs.append(imageURL)
        }
        if let text = extractedText {
            imageURLs.append(contentsOf: Self.cachedImageURLs(in: text))
        }
        await Task.detached(priority: .utility) {
            for imageURL in imageURLs {
                try? DatabaseManager.shared.clearCachedImageData(for: imageURL)
            }
            try? DatabaseManager.shared.clearCachedArticleContent(for: articleID)
            try? DatabaseManager.shared.clearCachedArticleSummary(for: articleID)
            try? DatabaseManager.shared.clearCachedArticleTranslation(for: articleID)
            try? DatabaseManager.shared.clearCachedComments(forArticleID: articleID)
        }.value

        translatedText = nil
        translatedTitle = nil
        translatedSummary = nil
        showingTranslation = false
        hasCachedTranslation = false
        summarizedText = nil
        hasCachedSummary = false
        showingSummary = false
        conversationComments = []

        let previousText = extractedText
        extractedText = nil
        await extractArticleContent()
        isExtracting = true

        if extractedText == nil, let previousText {
            let previousParagraphs = previousText.components(separatedBy: "\n\n").count
            if previousParagraphs > 1 || previousText.count < 500 {
                extractedText = previousText
                if !article.isEphemeral {
                    await Task.detached(priority: .utility) {
                        try? DatabaseManager.shared.cacheArticleContent(
                            previousText, for: articleID
                        )
                    }.value
                }
            }
        }

        loadConversationInBackground()
    }

    nonisolated private static let imageMarkerRegex = try? NSRegularExpression(
        pattern: #"\{\{IMG\}\}(.+?)\{\{/IMG\}\}"#,
        options: .dotMatchesLineSeparators
    )

    /// Linked images carry `{{IMG}}<url>{{IMGLINK}}<href>{{/IMGLINK}}{{/IMG}}`,
    /// so only the part before the link marker is the cached image URL.
    nonisolated private static func cachedImageURLs(in text: String) -> [String] {
        guard let regex = imageMarkerRegex else { return [] }
        let nsText = text as NSString
        let matches = regex.matches(
            in: text, range: NSRange(location: 0, length: nsText.length)
        )
        return matches.map { match in
            let payload = nsText.substring(with: match.range(at: 1))
            guard let linkRange = payload.range(of: "{{IMGLINK}}") else { return payload }
            return String(payload[payload.startIndex..<linkRange.lowerBound])
        }
    }
}
