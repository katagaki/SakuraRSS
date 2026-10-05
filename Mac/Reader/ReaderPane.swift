import Hanami
import SwiftUI

struct ReaderPane: View {

    let article: Article?
    let feed: Feed?
    let activity: BrowserPageActivity
    let feedManager: FeedManager
    var actions: TodayActions?
    /// The page the content was opened from, whose folder settings apply on Bookmarks.
    var context: BrowserLocation?
    var requestedMode: OpenArticleRequest.Mode?
    /// How the text of a page opened by link is found.
    var articleSource: ArticleSource?

    var body: some View {
        if let article, article.isYouTubeURL {
            YouTubeVideoPlayerView(article: article, feed: feed)
                .id(article.id)
        } else if let article, article.audioURL != nil {
            PodcastPlayerView(article: article, feed: feed, feedManager: feedManager)
                .id(article.id)
        } else if let article, let url = URL(string: article.url), let style = webPageStyle(for: article) {
            WebPageView(article: article, url: url, style: style, activity: activity)
                .id("\(article.id)|\(article.url)")
        } else if let article {
            ReaderView(
                article: article, feed: feed, activity: activity, feedManager: feedManager,
                actions: actions, articleSource: articleSource
            )
            .id("\(article.id)|\(article.url)")
        } else {
            ContentUnavailableView(
                String(localized: "Sidebar.SelectArticle", table: "Feeds"),
                systemImage: "doc.text",
                description: Text(String(localized: "Sidebar.SelectArticle.Description", table: "Feeds"))
            )
        }
    }

    private func webPageStyle(for article: Article) -> WebPageStyle? {
        let opening = ContentOpening(
            article: article, feedManager: feedManager, context: context, requestedMode: requestedMode
        )
        return WebPageStyle(mode: opening.mode)
    }
}
