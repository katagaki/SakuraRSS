import SwiftUI

/// Resolves the correct detail view for an `Article` navigation destination.
struct ArticleDestinationView: View {

    @Environment(FeedManager.self) private var feedManager
    let article: Article

    private var feedOpenMode: FeedOpenMode {
        guard let feed = feedManager.feed(forArticle: article),
              let raw = UserDefaults.standard.string(forKey: "openMode-\(feed.id)"),
              let mode = FeedOpenMode(rawValue: raw) else {
            return .inAppViewer
        }
        return mode
    }

    var body: some View {
        if article.isPodcastEpisode {
            PodcastEpisodeView(article: article)
        } else if article.isYouTubeURL {
            YouTubePlayerView(article: article)
        } else if feedOpenMode == .clearThisPage,
                  let url = URL(string: article.url) {
            ClearThisPageView(article: article, url: url)
        } else if feedOpenMode == .readability,
                  let url = URL(string: article.url) {
            ReadabilityView(article: article, url: url)
        } else if feedOpenMode == .archivePh,
                  let url = URL(string: article.url) {
            ArchivePhView(article: article, url: url)
        } else {
            ArticleDetailView(article: article)
        }
    }
}
