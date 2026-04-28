import SwiftUI

extension ArticleDetailView {

    var actionButtons: some View {
        HStack(spacing: 8) {
            if !isExtracting && displayText != nil {
                ActionButton(
                    systemImage: translateButtonSystemImage,
                    isLoading: isTranslating,
                    accessibilityLabel: translateButtonAccessibilityLabel,
                    glassID: "action.translate",
                    glassNamespace: glassNamespace
                ) {
                    handleTranslateTap()
                }

                if isAppleIntelligenceAvailable {
                    ActionButton(
                        systemImage: summarizeButtonSystemImage,
                        isLoading: isSummarizing,
                        accessibilityLabel: summarizeButtonAccessibilityLabel,
                        glassID: "action.summarize",
                        glassNamespace: glassNamespace
                    ) {
                        handleSummarizeTap()
                    }
                }
            }

            if let pdfURL = ArXivHelper.pdfURL(forArticleURL: article.url) {
                ActionButton(
                    systemImage: "doc.richtext",
                    accessibilityLabel: String(localized: "ArXiv.ViewPDF", table: "Integrations"),
                    glassID: "action.pdf",
                    glassNamespace: glassNamespace
                ) {
                    arXivPDFReference = ArXivPDFReference(
                        url: pdfURL,
                        title: article.title
                    )
                }
            }

            if article.hasLink && !article.isEphemeral {
                ActionButton(
                    systemImage: article.isYouTubeURL && YouTubeHelper.isAppInstalled
                        ? "play.rectangle" : "safari",
                    accessibilityLabel: String(localized: "Article.OpenInBrowser", table: "Articles"),
                    glassID: "action.openlink",
                    glassNamespace: glassNamespace
                ) {
                    openArticleURL()
                }
            }
        }
    }

    private var translateButtonSystemImage: String {
        if hasTranslationForCurrentMode && !isTranslating {
            return showingTranslation ? "doc.plaintext" : "translate"
        }
        return "translate"
    }

    private var translateButtonAccessibilityLabel: String {
        if hasTranslationForCurrentMode && !isTranslating {
            return showingTranslation
                ? String(localized: "Article.ShowOriginal", table: "Articles")
                : String(localized: "Article.ShowTranslation", table: "Articles")
        }
        return String(localized: "Article.Translate", table: "Articles")
    }

    private var summarizeButtonSystemImage: String {
        let hasAvailableSummary = (summarizedText != nil || hasCachedSummary) && !isSummarizing
        if hasAvailableSummary {
            return showingSummary ? "doc.plaintext" : "text.line.2.summary"
        }
        return "text.line.2.summary"
    }

    private var summarizeButtonAccessibilityLabel: String {
        let hasAvailableSummary = (summarizedText != nil || hasCachedSummary) && !isSummarizing
        if hasAvailableSummary {
            return showingSummary
                ? String(localized: "Article.ShowOriginal", table: "Articles")
                : String(localized: "Article.ShowSummary", table: "Articles")
        }
        return String(localized: "Article.Summarize", table: "Articles")
    }

    private func handleTranslateTap() {
        if hasTranslationForCurrentMode && !isTranslating {
            withAnimation(.smooth.speed(2.0)) {
                showingTranslation.toggle()
            }
        } else if !isTranslating {
            triggerTranslation()
        }
    }

    private func handleSummarizeTap() {
        let hasAvailableSummary = (summarizedText != nil || hasCachedSummary) && !isSummarizing
        if hasAvailableSummary && summarizedText != nil {
            withAnimation(.smooth.speed(2.0)) {
                showingSummary.toggle()
            }
        } else if !isSummarizing {
            Task {
                await summarizeArticle()
                if summarizedText != nil {
                    withAnimation(.smooth.speed(2.0)) {
                        showingSummary = true
                    }
                }
            }
        }
    }
}
