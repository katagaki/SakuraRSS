import SwiftUI

extension PodcastEpisodeView {

    @ViewBuilder
    var overflowMenu: some View {
        Menu {
            if hasSummary {
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

            if let shareURL = URL(string: article.url) {
                Divider()
                ShareLink(item: shareURL) {
                    Label(
                        String(localized: "Article.Share", table: "Articles"),
                        systemImage: "square.and.arrow.up"
                    )
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
                Label(
                    String(localized: "Article.ShowOriginalSummary", table: "Articles"),
                    systemImage: "arrow.uturn.backward"
                )
            }
            Button {
                withAnimation(.smooth.speed(2.0)) {
                    showingSummary = false
                }
            } label: {
                Label(
                    String(localized: "Article.ShowOriginalTranslation", table: "Articles"),
                    systemImage: "arrow.uturn.backward"
                )
            }
        } else if showingTranslation {
            Button {
                withAnimation(.smooth.speed(2.0)) {
                    showingTranslation = false
                }
            } label: {
                Label(
                    String(localized: "Article.ShowOriginal", table: "Articles"),
                    systemImage: "arrow.uturn.backward"
                )
            }
        } else if showingSummary {
            Button {
                withAnimation(.smooth.speed(2.0)) {
                    showingSummary = false
                }
            } label: {
                Label(
                    String(localized: "Article.ShowOriginal", table: "Articles"),
                    systemImage: "arrow.uturn.backward"
                )
            }
        }
    }

    var hasSummary: Bool {
        guard let summary = article.summary else { return false }
        return !summary.isEmpty
    }

    var translateLabel: String {
        if showingSummary {
            return String(localized: "Article.TranslateSummary", table: "Articles")
        }
        if translatedText != nil && !isTranslating {
            return String(localized: "Article.ShowTranslation", table: "Articles")
        }
        return String(localized: "Article.Translate", table: "Articles")
    }

    var summarizeLabel: String {
        if showingTranslation {
            return String(localized: "Article.SummarizeTranslation", table: "Articles")
        }
        let hasAvailableSummary = (summarizedText != nil || hasCachedSummary) && !isSummarizing
        if hasAvailableSummary {
            return String(localized: "Article.ShowSummary", table: "Articles")
        }
        return String(localized: "Article.Summarize", table: "Articles")
    }

    func handleToolbarTranslateTap() {
        if hasTranslationForCurrentMode && !isTranslating {
            withAnimation(.smooth.speed(2.0)) {
                showingTranslation.toggle()
            }
        } else if !isTranslating {
            triggerTranslation()
        }
    }

    func handleToolbarSummarizeTap() {
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
