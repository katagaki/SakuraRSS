import SwiftUI

extension IPadSidebarView {

    func shouldOpenExternally(_ article: Article) -> Bool {
        if article.isYouTubeURL && youTubeOpenMode == .youTubeApp {
            return true
        }
        return false
    }

    func openArticleExternally(_ article: Article) {
        feedManager.markRead(article)
        if article.isYouTubeURL && youTubeOpenMode == .youTubeApp {
            YouTubeHelper.openInApp(url: article.url)
        } else if article.isYouTubeURL && youTubeOpenMode == .browser {
            pendingYouTubeSafariURL = URL(string: article.url)
            showYouTubeSafari = true
        }
    }

    func handlePendingArticle(_ articleID: Int64) {
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            if let article = feedManager.article(byID: articleID) {
                if shouldOpenExternally(article) {
                    openArticleExternally(article)
                } else {
                    selectedArticle = article
                    ephemeralDestinations = []
                    feedManager.markRead(article)
                }
            }
            pendingArticleID = nil
        }
    }
}
