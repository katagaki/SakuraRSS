import SwiftUI
import Hanami

extension ArticleDetailView {

    /// Re-sent whenever the state behind these actions changes, since the
    /// bar holds them rather than re-reading the viewer.
    func reportBrowserArticleActions() {
        guard isBrowserChromeActive else {
            browserArticleActionsReporter?(nil)
            return
        }
        let actions = browserArticleActions
        browserArticleActionsReporter?(actions.isEmpty ? nil : actions)
    }

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

    /// The browser hides the top bar, so the viewer's trailing actions are
    /// handed to the bottom bar to present instead.
    var browserArticleActions: BrowserArticleActions {
        var actions = BrowserArticleActions()
        guard !previewMode else { return actions }

        if !article.isEphemeral {
            actions.isBookmarked = isBookmarked
            actions.toggleBookmark = {
                isBookmarked.toggle()
                feedManager.toggleBookmark(article)
            }
        }

        if !isExtracting, displayText != nil, !isInsecureArticle {
            #if !os(visionOS)
            if !showingTranslation {
                actions.translate = BrowserArticleActions.LabelledAction(
                    title: translateLabel,
                    systemImage: "translate",
                    isEnabled: !isTranslating,
                    perform: { handleToolbarTranslateTap() }
                )
            }
            #endif
            if isAppleIntelligenceAvailable, !showingSummary {
                actions.summarize = BrowserArticleActions.LabelledAction(
                    title: summarizeLabel,
                    systemImage: "text.line.3.summary",
                    isEnabled: !isSummarizing,
                    perform: { handleToolbarSummarizeTap() }
                )
            }
        }

        if includesOpenLinkAction, includesOpenInAppAction {
            actions.openInApp = BrowserArticleActions.LabelledAction(
                title: String(localized: "OpenInApp", table: "Articles"),
                systemImage: "play.rectangle",
                isEnabled: true,
                perform: { performOpenInApp() }
            )
        }

        actions.shareURL = URL(string: article.url)
        return actions
    }
}
