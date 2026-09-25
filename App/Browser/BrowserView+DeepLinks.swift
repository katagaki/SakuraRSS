import EnhancedNavigation
import SwiftUI
import Hanami

extension BrowserView {

    /// Cold launch sets the request before the feeds are loaded, so the row is
    /// looked up once they are in.
    func handlePendingArticleIfNeeded() {
        guard let articleID = pendingArticleID else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard pendingArticleID == articleID else { return }
            openPendingArticle(articleID)
            pendingArticleID = nil
        }
    }

    private func openPendingArticle(_ articleID: Int64) {
        guard let article = feedManager.article(byID: articleID) else { return }
        if article.isYouTubeURL, youTubeOpenMode == .youTubeApp {
            feedManager.markRead(article)
            YouTubeHelper.openInApp(url: article.url)
            return
        }
        store.openTab(pushing: article)
    }

    func handlePendingOpenRequestIfNeeded() {
        guard let request = pendingOpenRequest else { return }
        pendingOpenRequest = nil
        let article = Article.ephemeral(url: request.url, title: request.url)
        if article.isYouTubeURL, youTubeOpenMode == .youTubeApp {
            YouTubeHelper.openInApp(url: article.url)
            return
        }
        store.openTab(pushing: EphemeralArticleDestination(
            article: article, mode: request.mode, textMode: request.textMode
        ))
    }
}
