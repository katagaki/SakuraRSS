import Hanami
import SwiftUI

struct ReaderPane: View {

    let article: Article?
    let feed: Feed?
    let activity: BrowserPageActivity
    let feedManager: FeedManager
    var actions: TodayActions?

    var body: some View {
        if let article, article.isYouTubeURL {
            YouTubeVideoPlayerView(article: article, feed: feed)
                .id(article.id)
        } else if let article, article.audioURL != nil {
            PodcastPlayerView(article: article, feed: feed, feedManager: feedManager)
                .id(article.id)
        } else if let article {
            ReaderView(article: article, feed: feed, activity: activity, feedManager: feedManager, actions: actions)
                .id(article.id)
        } else {
            ContentUnavailableView(
                String(localized: "Sidebar.SelectArticle", table: "Feeds"),
                systemImage: "doc.text",
                description: Text(String(localized: "Sidebar.SelectArticle.Description", table: "Feeds"))
            )
        }
    }
}
