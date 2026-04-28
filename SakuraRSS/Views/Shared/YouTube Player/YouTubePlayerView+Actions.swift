import SwiftUI

extension YouTubePlayerView {

    var descriptionActionButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if hasDescription {
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
                                await summarizeDescription()
                                return summarizedText != nil
                            }
                        )
                    }
                }
                if let youtubeAppURL, UIApplication.shared.canOpenURL(youtubeAppURL) {
                    OpenLinkButton(
                        title: String(localized: "YouTube.OpenInApp", table: "Integrations"),
                        systemImage: "play.rectangle",
                        action: { UIApplication.shared.open(youtubeAppURL) }
                    )
                }
                if article.hasLink && !article.isEphemeral {
                    OpenLinkButton(
                        title: String(localized: "YouTube.OpenInBrowser", table: "Integrations"),
                        systemImage: "safari",
                        action: {
                            if let url = URL(string: article.url) {
                                openURL(url)
                            }
                        }
                    )
                }
            }
            .buttonStyle(.bordered)
            .tint(.primary)
            .padding(.horizontal)
        }
        .padding(.top, 12)
    }
}
