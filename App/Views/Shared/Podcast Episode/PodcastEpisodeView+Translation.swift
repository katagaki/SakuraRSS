import SwiftUI
@preconcurrency import Translation

extension PodcastEpisodeView {
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
            }
        } else {
            let source = article.summary ?? ""
            guard !source.isEmpty else { return }
            do {
                let response = try await session.translate(source)
                translatedText = response.targetText
                showingTranslation = true
                try? DatabaseManager.shared.cacheArticleTranslation(
                    title: article.title,
                    text: response.targetText,
                    for: article.id
                )
            } catch {
            }
        }
    }
}
