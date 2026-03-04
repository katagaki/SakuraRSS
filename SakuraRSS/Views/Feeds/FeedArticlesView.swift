import SwiftUI

struct FeedArticlesView: View {

    @Environment(FeedManager.self) var feedManager
    let feed: Feed

    private static let pageSize = 50

    @State private var displayLimit: Int = FeedArticlesView.pageSize

    private var hasMore: Bool {
        feedManager.articleCount(for: feed) > displayLimit
    }

    var body: some View {
        ArticleListView(
            articles: feedManager.articles(for: feed, limit: displayLimit),
            title: feed.title,
            feedKey: String(feed.id),
            isVideoFeed: feed.isVideoFeed,
            isPodcastFeed: feed.isPodcast,
            isFeedViewDomain: feed.isFeedViewDomain,
            onLoadMore: hasMore ? {
                displayLimit += Self.pageSize
            } : nil
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
