import SwiftUI

extension ArticleDetailView {

    @ToolbarContentBuilder
    var iPadArticleToolbar: some ToolbarContent {
        if hasIPadIntelligenceActions {
            ToolbarItemGroup(placement: .topBarTrailing) {
                iPadIntelligenceActions
            }
            #if !os(visionOS)
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            #endif
        }
        if hasIPadOpenActions {
            ToolbarItemGroup(placement: .topBarTrailing) {
                iPadOpenActions
            }
            #if !os(visionOS)
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            #endif
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            iPadShareActions
        }
    }

    private var hasIPadIntelligenceActions: Bool {
        !isExtracting && displayText != nil
    }

    private var hasIPadOpenActions: Bool {
        includesOpenInAppAction || includesArXivAction || includesOpenLinkAction
    }

    @ViewBuilder
    private var iPadIntelligenceActions: some View {
        #if !os(visionOS)
        if showingTranslation {
            Button {
                withAnimation(.smooth.speed(2.0)) {
                    showingTranslation = false
                }
            } label: {
                Label(showingSummary
                      ? String(localized: "Article.ShowOriginalTranslation", table: "Articles")
                      : String(localized: "Article.ShowOriginal", table: "Articles"),
                      systemImage: "arrow.uturn.backward")
            }
        } else {
            Button {
                handleToolbarTranslateTap()
            } label: {
                Label(translateLabel, systemImage: "translate")
            }
            .disabled(isTranslating)
        }
        #endif

        if isAppleIntelligenceAvailable {
            if showingSummary {
                Button {
                    withAnimation(.smooth.speed(2.0)) {
                        showingSummary = false
                    }
                } label: {
                    Label(showingTranslation
                          ? String(localized: "Article.ShowOriginalSummary", table: "Articles")
                          : String(localized: "Article.ShowOriginal", table: "Articles"),
                          systemImage: "arrow.uturn.backward")
                }
            } else {
                Button {
                    handleToolbarSummarizeTap()
                } label: {
                    Label(summarizeLabel, systemImage: "text.line.3.summary")
                }
                .disabled(isSummarizing)
            }
        }
    }

    @ViewBuilder
    private var iPadOpenActions: some View {
        if includesOpenInAppAction {
            Button {
                performOpenInApp()
            } label: {
                Label(String(localized: "OpenInApp", table: "Articles"),
                      systemImage: "play.rectangle")
            }
        }
        if includesArXivAction {
            Button {
                performOpenArXivPDF()
            } label: {
                Label(String(localized: "ArXiv.ViewPDF", table: "Integrations"),
                      systemImage: "doc.richtext")
            }
        }
        if includesOpenLinkAction {
            iPadOpenInBrowserItem
        }
    }

    @ViewBuilder
    private var iPadOpenInBrowserItem: some View {
        if let linkedURL = linkedArticleURL,
           let articleURL = URL(string: article.url),
           let articleHost = articleURL.host?.lowercased(),
           let linkedHost = linkedURL.host?.lowercased(),
           articleHost != linkedHost {
            Menu {
                Button {
                    openURL(articleURL)
                } label: {
                    Label(displayHost(articleHost), systemImage: "arrow.up.forward.square")
                }
                Button {
                    openURL(linkedURL)
                } label: {
                    Label(displayHost(linkedHost), systemImage: "arrow.up.forward.square")
                }
            } label: {
                Label(String(localized: "Article.OpenInBrowser", table: "Articles"),
                      systemImage: "arrow.up.forward.square")
            }
        } else {
            Button {
                performOpenInBrowser()
            } label: {
                Label(String(localized: "Article.OpenInBrowser", table: "Articles"),
                      systemImage: "arrow.up.forward.square")
            }
        }
    }

    @ViewBuilder
    private var iPadShareActions: some View {
        if !article.isEphemeral {
            Button {
                isBookmarked.toggle()
                feedManager.toggleBookmark(article)
            } label: {
                Label(isBookmarked
                      ? String(localized: "Article.RemoveBookmark", table: "Articles")
                      : String(localized: "Article.Bookmark", table: "Articles"),
                      systemImage: isBookmarked ? "bookmark.fill" : "bookmark")
            }
        }
        if let shareURL = URL(string: article.url) {
            ShareLink(item: shareURL) {
                Label(String(localized: "Article.Share", table: "Articles"),
                      systemImage: "square.and.arrow.up")
            }
        }
    }
}
