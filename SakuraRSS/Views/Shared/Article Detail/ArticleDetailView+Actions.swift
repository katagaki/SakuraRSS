import SwiftUI

extension ArticleDetailView {

    var actionButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if !isExtracting && displayText != nil {
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

                if let pdfURL = ArXivHelper.pdfURL(forArticleURL: article.url) {
                    OpenLinkButton(
                        title: "ArXiv.ViewPDF",
                        systemImage: "doc.richtext",
                        action: {
                            arXivPDFReference = ArXivPDFReference(
                                url: pdfURL,
                                title: article.title
                            )
                        }
                    )
                }

                OpenLinkButton(
                    title: "Article.OpenInBrowser",
                    systemImage: article.isYouTubeURL && YouTubeHelper.isAppInstalled
                        ? "play.rectangle" : "safari",
                    action: { openArticleURL() }
                )
            }
            .buttonStyle(.bordered)
            .tint(.primary)
            .padding(.horizontal)
        }
        .padding(.top)
    }
}
