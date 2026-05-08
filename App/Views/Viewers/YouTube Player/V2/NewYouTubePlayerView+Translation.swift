import SwiftUI
#if !os(visionOS)
@preconcurrency import Translation

extension NewYouTubePlayerView {

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
                if !article.isEphemeral {
                    try? DatabaseManager.shared.cacheTranslatedSummary(
                        response.targetText, for: article.id
                    )
                }
            } catch {
            }
        } else {
            let source = descriptionSource ?? ""
            guard !ContentBlock.plainText(from: source).isEmpty else { return }
            do {
                let result = try await ContentBlock.translateArticleContent(
                    title: nil, markerText: source, session: session
                )
                translatedText = result.text
                hasCachedTranslation = true
                showingTranslation = true
                if !article.isEphemeral {
                    try? DatabaseManager.shared.cacheArticleTranslation(
                        title: nil, text: result.text, for: article.id
                    )
                }
            } catch {
            }
        }
    }
}
#endif
