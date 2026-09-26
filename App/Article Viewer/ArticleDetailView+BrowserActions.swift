import SwiftUI
import Hanami

extension ArticleDetailView {

    /// None of the viewer's work reports a count, so the bar marquees for as
    /// long as any of it runs. The address bar is the only chrome the browser
    /// leaves, and the menu these actions live in closes on the tap that
    /// starts them.
    func reportBrowserProgress() {
        let isWorking = isExtracting || isTranslating || isSummarizing
        guard isBrowserChromeActive, isWorking else {
            browserPageProgressReporter?(nil)
            return
        }
        browserPageProgressReporter?(.indeterminate)
    }

    /// The browser hides the top bar, so the viewer's trailing actions go in
    /// the omnibox instead.
    var showsBrowserArticleMenu: Bool {
        isBrowserChromeActive && !previewMode
    }

    private var hasTransformableText: Bool {
        !isExtracting && displayText != nil && !isInsecureArticle
    }

    private var canTranslateInBrowser: Bool {
        #if os(visionOS)
        false
        #else
        hasTransformableText && !showingTranslation
        #endif
    }

    private var canSummarizeInBrowser: Bool {
        hasTransformableText && isAppleIntelligenceAvailable && !showingSummary
    }

    /// Read straight off the viewer's state whenever the omnibox draws it, so
    /// nothing has to be re-sent as that state changes.
    var browserArticleMenu: some View {
        Menu(String(localized: "Tabs.More"), systemImage: "ellipsis") {
            if !article.isEphemeral {
                Button {
                    isBookmarked.toggle()
                    feedManager.toggleBookmark(article)
                } label: {
                    Label(
                        String(localized: isBookmarked ? "Article.RemoveBookmark" : "Article.Bookmark",
                               table: "Articles"),
                        systemImage: isBookmarked ? "bookmark.fill" : "bookmark"
                    )
                }
            }

            if canTranslateInBrowser || canSummarizeInBrowser {
                Divider()
                if canTranslateInBrowser {
                    Button(translateLabel, systemImage: "translate") {
                        handleToolbarTranslateTap()
                    }
                    .disabled(isTranslating)
                }
                if canSummarizeInBrowser {
                    Button(summarizeLabel, systemImage: "text.line.3.summary") {
                        handleToolbarSummarizeTap()
                    }
                    .disabled(isSummarizing)
                }
            }

            if includesOpenLinkAction, includesOpenInAppAction {
                Divider()
                Button(String(localized: "OpenInApp", table: "Articles"), systemImage: "play.rectangle") {
                    performOpenInApp()
                }
            }

            if let shareURL = URL(string: article.url) {
                Divider()
                ShareLink(item: shareURL) {
                    Label(String(localized: "Article.Share", table: "Articles"),
                          systemImage: "square.and.arrow.up")
                }
            }
        }
    }
}
