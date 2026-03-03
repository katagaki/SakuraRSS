import SwiftUI

struct FeedArticlesView: View {

    @Environment(FeedManager.self) var feedManager
    let feed: Feed
    var body: some View {
        ArticleListView(
            articles: feedManager.articles(for: feed),
            title: feed.title,
            feedKey: String(feed.id),
            isVideoFeed: feed.isVideoFeed,
            isPodcastFeed: feed.isPodcast,
            isFeedViewDomain: feed.isFeedViewDomain
        )
        .refreshable {
            try? await feedManager.refreshFeed(feed)
        }
        .safeAreaInset(edge: .bottom, alignment: .leading, spacing: 0) {
            FeedToolbar {
                feedManager.markAllRead(feed: feed)
            }
        }
    }
}
