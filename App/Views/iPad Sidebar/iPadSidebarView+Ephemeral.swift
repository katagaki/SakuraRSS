import SwiftUI

extension IPadSidebarView {

    /// Routes a `sakura://open` request to either the in-app YouTube player
    /// or to the standard article-detail flow with the requested viewer mode.
    func handlePendingOpenRequest(_ request: OpenArticleRequest) {
        let article = Article.ephemeral(url: request.url, title: request.url)
        if article.isYouTubeURL {
            switch youTubeOpenMode {
            case .inAppPlayer:
                selectedArticle = article
                ephemeralDestinations = []
            case .youTubeApp:
                YouTubeHelper.openInApp(url: article.url)
            case .browser:
                pendingYouTubeSafariURL = URL(string: article.url)
                showYouTubeSafari = true
            }
        } else {
            selectedArticle = nil
            ephemeralDestinations.append(EphemeralArticleDestination(
                article: article, mode: request.mode, textMode: request.textMode
            ))
        }
        pendingOpenRequest = nil
    }
}
