import SwiftUI

@MainActor
protocol ArticleActions {
    var article: Article { get }
    var isExtracting: Bool { get }
    var displayText: String? { get }
    var isAppleIntelligenceAvailable: Bool { get }

    var hasTranslationForCurrentMode: Bool { get }
    var hasTranslatedFullText: Bool { get }
    var isTranslating: Bool { get }
    var showingTranslation: Bool { get nonmutating set }

    var summarizedText: String? { get }
    var hasCachedSummary: Bool { get }
    var isSummarizing: Bool { get }
    var showingSummary: Bool { get nonmutating set }

    var glassNamespace: Namespace.ID { get }

    var includesArXivAction: Bool { get }
    var includesOpenLinkAction: Bool { get }

    func performTranslate()
    func performSummarize() async
    func performOpenArXivPDF()
    func performOpenLink()
}

extension ArticleActions {

    var includesArXivAction: Bool {
        ArXivHelper.pdfURL(forArticleURL: article.url) != nil
    }

    var includesOpenLinkAction: Bool {
        article.hasLink && !article.isEphemeral
    }

    func performOpenArXivPDF() {}

    @ViewBuilder
    var sharedActionButtons: some View {
        HStack(spacing: 8) {
            if !isExtracting && displayText != nil {
                ActionButton(
                    systemImage: "translate",
                    isLoading: isTranslating,
                    isTinted: showingTranslation,
                    accessibilityLabel: translateButtonAccessibilityLabel,
                    glassID: "action.translate",
                    glassNamespace: glassNamespace
                ) {
                    handleTranslateTap()
                }

                if isAppleIntelligenceAvailable {
                    ActionButton(
                        systemImage: "text.line.3.summary",
                        isLoading: isSummarizing,
                        isTinted: showingSummary,
                        accessibilityLabel: summarizeButtonAccessibilityLabel,
                        glassID: "action.summarize",
                        glassNamespace: glassNamespace
                    ) {
                        handleSummarizeTap()
                    }
                }
            }

            if includesArXivAction {
                ActionButton(
                    systemImage: "doc.richtext",
                    accessibilityLabel: String(localized: "ArXiv.ViewPDF", table: "Integrations"),
                    glassID: "action.pdf",
                    glassNamespace: glassNamespace
                ) {
                    performOpenArXivPDF()
                }
            }

            if includesOpenLinkAction {
                ActionButton(
                    systemImage: article.isYouTubeURL && YouTubeHelper.isAppInstalled
                        ? "play.rectangle" : "safari",
                    accessibilityLabel: String(localized: "Article.OpenInBrowser", table: "Articles"),
                    glassID: "action.openlink",
                    glassNamespace: glassNamespace
                ) {
                    performOpenLink()
                }
            }
        }
    }

    private var translateButtonAccessibilityLabel: String {
        if hasTranslationForCurrentMode && !isTranslating {
            return showingTranslation
                ? String(localized: "Article.ShowOriginal", table: "Articles")
                : String(localized: "Article.ShowTranslation", table: "Articles")
        }
        return String(localized: "Article.Translate", table: "Articles")
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
            performTranslate()
        }
    }

    private func handleSummarizeTap() {
        let hasAvailableSummary = (summarizedText != nil || hasCachedSummary) && !isSummarizing
        if hasAvailableSummary && summarizedText != nil {
            withAnimation(.smooth.speed(2.0)) {
                if showingSummary && showingTranslation && !hasTranslatedFullText {
                    showingTranslation = false
                }
                showingSummary.toggle()
            }
        } else if !isSummarizing {
            Task {
                await performSummarize()
                if summarizedText != nil {
                    withAnimation(.smooth.speed(2.0)) {
                        showingSummary = true
                    }
                }
            }
        }
    }
}
