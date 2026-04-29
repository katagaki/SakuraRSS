import SwiftUI

extension PodcastEpisodeView {

    var actionButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                TranslateButton(
                    hasTranslation: hasTranslationForCurrentMode,
                    isTranslating: isTranslating,
                    showingTranslation: $showingTranslation,
                    onTranslate: { triggerTranslation() }
                )
                if isAppleIntelligenceAvailable {
                    SummarizeButton(
                        summarizedText: summarizedText,
                        hasCachedSummary: hasCachedSummary,
                        isSummarizing: isSummarizing,
                        showingSummary: $showingSummary,
                        onSummarize: {
                            await summarizeArticle()
                            return summarizedText != nil
                        }
                    )
                }
            }
            .buttonStyle(.bordered)
            .tint(.primary)
            .padding(.horizontal)
        }
    }
}
