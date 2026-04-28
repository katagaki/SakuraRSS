import SwiftUI

extension ArticleDetailView: ArticleActions {

    @ViewBuilder
    var articleOpenToolbarItems: some View {
        if includesArXivAction {
            Button {
                performOpenArXivPDF()
            } label: {
                Image(systemName: "doc.richtext")
            }
            .accessibilityLabel(String(localized: "ArXiv.ViewPDF", table: "Integrations"))
        }
    }

    @ViewBuilder
    var articleOverflowMenu: some View {
        Menu {
            if !isExtracting && displayText != nil {
                if !showingTranslation {
                    Button {
                        handleToolbarTranslateTap()
                    } label: {
                        Label(translateLabel, systemImage: "translate")
                    }
                    .disabled(isTranslating)
                }

                if isAppleIntelligenceAvailable, !showingSummary {
                    Button {
                        handleToolbarSummarizeTap()
                    } label: {
                        Label(summarizeLabel, systemImage: "text.line.3.summary")
                    }
                    .disabled(isSummarizing)
                }

                if showingTranslation || showingSummary {
                    revertActions
                }
            }

            if includesOpenLinkAction {
                Divider()
                if includesOpenInAppAction {
                    Button {
                        performOpenInApp()
                    } label: {
                        Label(String(localized: "OpenInApp", table: "Articles"),
                              systemImage: "play.rectangle")
                    }
                }
                Button {
                    performOpenInBrowser()
                } label: {
                    Label(String(localized: "Article.OpenInBrowser", table: "Articles"),
                          systemImage: "safari")
                }
            }

            if let shareURL = URL(string: article.url) {
                Divider()
                ShareLink(item: shareURL) {
                    Label(String(localized: "Article.Share", table: "Articles"),
                          systemImage: "square.and.arrow.up")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
        }
    }

    @ViewBuilder
    private var revertActions: some View {
        if showingTranslation && showingSummary {
            Button {
                withAnimation(.smooth.speed(2.0)) {
                    showingTranslation = false
                }
            } label: {
                Label(String(localized: "Article.ShowOriginalSummary", table: "Articles"),
                      systemImage: "arrow.uturn.backward")
            }
            Button {
                withAnimation(.smooth.speed(2.0)) {
                    showingSummary = false
                }
            } label: {
                Label(String(localized: "Article.ShowOriginalTranslation", table: "Articles"),
                      systemImage: "arrow.uturn.backward")
            }
        } else if showingTranslation {
            Button {
                withAnimation(.smooth.speed(2.0)) {
                    showingTranslation = false
                }
            } label: {
                Label(String(localized: "Article.ShowOriginal", table: "Articles"),
                      systemImage: "arrow.uturn.backward")
            }
        } else if showingSummary {
            Button {
                withAnimation(.smooth.speed(2.0)) {
                    showingSummary = false
                }
            } label: {
                Label(String(localized: "Article.ShowOriginal", table: "Articles"),
                      systemImage: "arrow.uturn.backward")
            }
        }
    }

    var includesOpenInAppAction: Bool {
        article.isYouTubeURL && YouTubeHelper.isAppInstalled
    }

    func performOpenInBrowser() {
        if article.isYouTubeURL {
            showYouTubeSafari = true
        } else if let url = URL(string: article.url) {
            openURL(url)
        }
    }

    func performOpenInApp() {
        if article.isYouTubeURL {
            switch youTubeOpenMode {
            case .inAppPlayer:
                showYouTubePlayer = true
            case .youTubeApp:
                YouTubeHelper.openInApp(url: article.url)
            case .browser:
                YouTubeHelper.openInApp(url: article.url)
            }
        }
    }

    func performTranslate() {
        triggerTranslation()
    }

    func performSummarize() async {
        await summarizeArticle()
    }

    func performOpenArXivPDF() {
        guard let pdfURL = ArXivHelper.pdfURL(forArticleURL: article.url) else { return }
        arXivPDFReference = ArXivPDFReference(url: pdfURL, title: article.title)
    }

    private var translateLabel: String {
        if showingSummary {
            return String(localized: "Article.TranslateSummary", table: "Articles")
        }
        if (translatedText != nil || hasCachedTranslation) && !isTranslating {
            return String(localized: "Article.ShowTranslation", table: "Articles")
        }
        return String(localized: "Article.Translate", table: "Articles")
    }

    private var summarizeLabel: String {
        if showingTranslation {
            return String(localized: "Article.SummarizeTranslation", table: "Articles")
        }
        let hasAvailableSummary = (summarizedText != nil || hasCachedSummary) && !isSummarizing
        if hasAvailableSummary {
            return String(localized: "Article.ShowSummary", table: "Articles")
        }
        return String(localized: "Article.Summarize", table: "Articles")
    }

    private func handleToolbarTranslateTap() {
        if hasTranslationForCurrentMode && !isTranslating {
            withAnimation(.smooth.speed(2.0)) {
                showingTranslation.toggle()
            }
        } else if !isTranslating {
            performTranslate()
        }
    }

    private func handleToolbarSummarizeTap() {
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
