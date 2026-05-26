import SwiftUI
import Hanami

/// Resolves the correct detail view for an `Article` navigation destination.
struct ArticleDestinationView: View {

    @Environment(FeedManager.self) private var feedManager
    @Environment(\.youTubePlayerSession) private var youTubeSession
    @Environment(\.podcastAudioPlayer) private var audioPlayer
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

    /// Stable per-article identity. Ephemeral articles all share `id == 0`, so
    /// they key on the URL instead; otherwise navigating between two ephemeral
    /// articles (or any reused detail view) leaves the previous content on
    /// screen because the id-keyed loader never re-runs.
    private var articleIdentity: String {
        article.isEphemeral ? article.url : String(article.id)
    }

    var body: some View {
        let article = rawArticle
        Group {
            if article.isPodcastEpisode {
                PodcastEpisodeView(article: article, audioPlayer: audioPlayer)
            } else if article.isYouTubeURL {
                YouTubePlayerView(article: article, session: youTubeSession)
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
        .id(articleIdentity)
    }
}
