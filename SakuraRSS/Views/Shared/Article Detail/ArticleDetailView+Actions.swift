import SwiftUI

extension ArticleDetailView {

    var actionButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if !isExtracting && displayText != nil {
                    translationButton
                    if isAppleIntelligenceAvailable {
                        summarizationButton
                    }
                }

                Button {
                    openArticleURL()
                } label: {
                    Label(
                        String(localized: "Article.OpenInBrowser"),
                        systemImage: (
                            article.isYouTubeURL && YouTubeHelper.isAppInstalled ? "play.rectangle" : "safari"
                        )
                    )
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)
                }
            }
            .buttonStyle(.bordered)
            .tint(.primary)
            .padding(.horizontal)
        }
        .padding(.top)
    }

    @ViewBuilder
    private var translationButton: some View {
        if hasTranslationForCurrentMode && !isTranslating {
            Button {
                withAnimation(.smooth.speed(2.0)) {
                    showingTranslation.toggle()
                }
            } label: {
                Label(
                    String(localized: showingTranslation
                           ? "Article.ShowOriginal"
                           : "Article.ShowTranslation"),
                    systemImage: showingTranslation
                        ? "doc.plaintext" : "translate"
                )
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        } else {
            Button {
                triggerTranslation()
            } label: {
                Label(
                    String(localized: "Article.Translate"),
                    systemImage: "translate"
                )
                .opacity(isTranslating ? 0 : 1)
                .overlay {
                    if isTranslating {
                        ProgressView()
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
            .disabled(isTranslating)
            .animation(.smooth.speed(2.0), value: isTranslating)
        }
    }

    @ViewBuilder
    private var summarizationButton: some View {
        if (summarizedText != nil || hasCachedSummary) && !isSummarizing {
            Button {
                if summarizedText == nil {
                    Task {
                        await summarizeArticle()
                        if summarizedText != nil {
                            withAnimation(.smooth.speed(2.0)) {
                                showingSummary = true
                            }
                        }
                    }
                } else {
                    withAnimation(.smooth.speed(2.0)) {
                        showingSummary.toggle()
                    }
                }
            } label: {
                Label(
                    String(localized: showingSummary
                           ? "Article.ShowOriginal"
                           : "Article.ShowSummary"),
                    systemImage: showingSummary
                        ? "doc.plaintext" : "apple.intelligence"
                )
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        } else {
            Button {
                Task {
                    await summarizeArticle()
                    if summarizedText != nil {
                        withAnimation(.smooth.speed(2.0)) {
                            showingSummary = true
                        }
                    }
                }
            } label: {
                Label(
                    String(localized: "Article.Summarize"),
                    systemImage: "apple.intelligence"
                )
                .opacity(isSummarizing ? 0 : 1)
                .overlay {
                    if isSummarizing {
                        ProgressView()
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
            .disabled(isSummarizing)
            .animation(.smooth.speed(2.0), value: isSummarizing)
        }
    }
}
