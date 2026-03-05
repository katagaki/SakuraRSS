import SwiftUI
@preconcurrency import Translation

extension ArticleDetailView {
    func triggerTranslation() {
        if translationConfig == nil {
            translationConfig = .init()
        } else {
            translationConfig?.invalidate()
        }
    }

    func handleTranslation(session: TranslationSession) async {
        isTranslating = true
        defer { isTranslating = false }

        if showingSummary, let summarizedText {
            guard !summarizedText.isEmpty else { return }
            do {
                let response = try await session.translate(summarizedText)
                translatedSummary = response.targetText
                showingTranslation = true
                try? DatabaseManager.shared.cacheTranslatedSummary(
                    response.targetText, for: article.id
                )
            } catch {
                // Translation failed; user can retry
            }
        } else {
            let source = ContentBlock.plainText(from: extractedText ?? article.summary ?? "")
            guard !source.isEmpty else { return }
            do {
                let requests = [
                    TranslationSession.Request(sourceText: article.title),
                    TranslationSession.Request(sourceText: source)
                ]
                let responses = try await session.translations(from: requests)
                if responses.count >= 2 {
                    translatedTitle = responses[0].targetText
                    translatedText = responses[1].targetText
                    hasCachedTranslation = true
                    showingTranslation = true
                    try? DatabaseManager.shared.cacheArticleTranslation(
                        title: responses[0].targetText,
                        text: responses[1].targetText,
                        for: article.id
                    )
                }
            } catch {
                // Translation failed; user can retry
            }
        }
    }
}
