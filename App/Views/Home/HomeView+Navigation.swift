import SwiftUI

extension HomeView {

    func handlePendingOpenRequestIfNeeded() {
        guard let request = pendingOpenRequest else { return }
        handlePendingOpenRequest(request)
    }

    func handlePendingOpenRequest(_ request: OpenArticleRequest) {
        // Suppress saved-state restoration that would otherwise stomp on our
        // navigation push when launched cold from the extension.
        hasRestored = true
        let article = Article.ephemeral(url: request.url, title: request.url)
        if article.isYouTubeURL {
            switch youTubeOpenMode {
            case .inAppPlayer:
                MediaPresenter.shared.presentYouTube(article)
            case .youTubeApp:
                YouTubeHelper.openInApp(url: article.url)
            case .browser:
                pendingYouTubeSafariURL = URL(string: article.url)
                showYouTubeSafari = true
            }
        } else {
            path.append(EphemeralArticleDestination(
                article: article, mode: request.mode, textMode: request.textMode
            ))
        }
        pendingOpenRequest = nil
    }

    func restorePath() {
        guard !feedManager.feeds.isEmpty else { return }
        hasRestored = true

        if savedFeedID >= 0,
           let feed = feedManager.feeds.first(where: { $0.id == Int64(savedFeedID) }) {
            path.append(feed)
            if savedArticleID >= 0,
               let article = feedManager.article(byID: Int64(savedArticleID)) {
                appendArticle(article)
            }
        } else if savedArticleID >= 0,
                  let article = feedManager.article(byID: Int64(savedArticleID)) {
            appendArticle(article)
        }
    }

    func appendArticle(_ article: Article) {
        if article.isPodcastEpisode {
            MediaPresenter.shared.presentPodcast(article)
            savedArticleID = -1
        } else if article.isYouTubeURL {
            // Restoration for YouTube articles is skipped since the player
            // sheet doesn't survive app relaunch.
            savedArticleID = -1
        } else {
            path.append(article)
        }
    }
}
