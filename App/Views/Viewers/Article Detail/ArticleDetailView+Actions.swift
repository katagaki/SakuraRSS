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
                #if !os(visionOS)
                if !showingTranslation {
                    Button {
                        handleToolbarTranslateTap()
                    } label: {
                        Label(translateLabel, systemImage: "translate")
                    }
                    .disabled(isTranslating)
                }
                #endif

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
                openInBrowserMenuItem
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

    @ViewBuilder
    var openInBrowserMenuItem: some View {
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

    func performOpenInBrowser() {
        if article.isYouTubeURL {
            showYouTubeSafari = true
        } else if let url = URL(string: article.url) {
            openURL(url)
        }
    }

    func resolveLinkedArticleURL() async {
        guard let feed = feedManager.feed(forArticle: article),
              feed.isRedditFeed else {
            linkedArticleURL = nil
            return
        }
        if let result = try? await RedditPostFetcher.shared.fetchContent(for: article),
           case .linkedArticle(let url) = result {
            linkedArticleURL = url
        }
    }

    func displayHost(_ host: String) -> String {
        host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    func performOpenInApp() {
        if article.isYouTubeURL {
            switch youTubeOpenMode {
            case .inAppPlayer:
                MediaPresenter.shared.presentYouTube(article)
            case .youTubeApp:
                YouTubeHelper.openInApp(url: article.url)
            case .browser:
                YouTubeHelper.openInApp(url: article.url)
            }
        }
    }

    func performTranslate() {
        #if !os(visionOS)
        triggerTranslation()
        #endif
    }

    func performSummarize() async {
        await summarizeArticle()
    }

    func performOpenArXivPDF() {
        guard let pdfURL = ArXivHelper.pdfURL(forArticleURL: article.url) else { return }
        arXivPDFReference = ArXivPDFReference(url: pdfURL, title: article.title)
    }

    func handleLinkTap(_ url: URL) {
        switch linkOpenMode {
        case .browser:
            openURL(url)
        case .inAppViewer:
            if let navigateToEphemeralArticle {
                let ephemeral = Article.ephemeral(url: url.absoluteString, title: url.absoluteString)
                navigateToEphemeralArticle(EphemeralArticleDestination(
                    article: ephemeral, mode: .viewer, textMode: .auto
                ))
            } else {
                inAppLinkURL = url
            }
        }
    }

    var translateLabel: String {
        if showingSummary {
            return String(localized: "Article.TranslateSummary", table: "Articles")
        }
        if (translatedText != nil || hasCachedTranslation) && !isTranslating {
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
            performTranslate()
        }
    }

    func handleToolbarSummarizeTap() {
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
