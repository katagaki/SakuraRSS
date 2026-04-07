import SwiftUI
@preconcurrency import Translation

extension YouTubePlayerView {

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
            let source = ContentBlock.plainText(from: descriptionSource ?? "")
            guard !source.isEmpty else { return }
            do {
                let response = try await session.translate(source)
                translatedText = response.targetText
                hasCachedTranslation = true
                showingTranslation = true
                try? DatabaseManager.shared.cacheArticleTranslation(
                    title: nil, text: response.targetText, for: article.id
                )
            } catch {
                // Translation failed; user can retry
            }
        }
    }
}
