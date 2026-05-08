import SwiftUI

/// Resolves the correct detail view for an `Article` navigation destination.
struct ArticleDestinationView: View {

    @Environment(FeedManager.self) private var feedManager
    let article: Article
    /// When non-nil, overrides the per-feed `FeedOpenMode` lookup (used for
    /// ephemeral articles opened via `sakura://open`).
    var overrideMode: OpenArticleRequest.Mode?
    /// Used when `overrideMode == .viewer` to pre-seed the article source.
    var overrideTextMode: OpenArticleRequest.TextMode?

    init(
        article: Article,
        overrideMode: OpenArticleRequest.Mode? = nil,
        overrideTextMode: OpenArticleRequest.TextMode? = nil
    ) {
        self.article = article
        self.overrideMode = overrideMode
        self.overrideTextMode = overrideTextMode
    }

    /// The article without Content Overrides applied. Lists override the display, but the
    /// viewer always reads the original RSS fields straight from the DB.
    private var rawArticle: Article {
        guard !article.isEphemeral else { return article }
        return feedManager.article(byID: article.id) ?? article
    }

    private var effectiveOpenMode: FeedOpenMode {
        if let overrideMode {
            switch overrideMode {
            case .viewer: return .inAppViewer
            case .clearThisPage: return .clearThisPage
            case .readability: return .readability
            case .archiveToday: return .archivePh
            }
        }
        guard let feed = feedManager.feed(forArticle: article),
              let raw = UserDefaults.standard.string(forKey: "openMode-\(feed.id)"),
              let mode = FeedOpenMode(rawValue: raw) else {
            return .inAppViewer
        }
        return mode
    }

    var body: some View {
        let article = rawArticle
        if article.isPodcastEpisode {
            PodcastEpisodeView(article: article)
        } else if article.isYouTubeURL {
            if NewYouTubePlayerToggleStore.shared.isEnabled {
                NewYouTubePlayerView(article: article)
            } else {
                YouTubePlayerView(article: article)
            }
        } else if effectiveOpenMode == .clearThisPage,
                  let url = URL(string: article.url) {
            ClearThisPageView(article: article, url: url)
        } else if effectiveOpenMode == .readability,
                  let url = URL(string: article.url) {
            ReadabilityView(article: article, url: url)
        } else if effectiveOpenMode == .archivePh,
                  let url = URL(string: article.url) {
            ArchivePhView(article: article, url: url)
        } else {
            ArticleDetailView(
                article: article,
                ephemeralTextMode: article.isEphemeral ? overrideTextMode : nil
            )
        }
    }
}
