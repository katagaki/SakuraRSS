import SwiftUI

struct FeedArticlesView: View {

    @Environment(FeedManager.self) var feedManager
    let feed: Feed

    private static let pageSize = 50

    @State private var displayLimit: Int = FeedArticlesView.pageSize
    @AppStorage("Display.MarkAllReadPosition") private var markAllReadPosition: MarkAllReadPosition = .bottom
    @AppStorage("Instagram.HideReels") private var hideReels: Bool = false

    private var currentFeed: Feed {
        feedManager.feeds.first(where: { $0.id == feed.id }) ?? feed
    }

    private var hasMore: Bool {
        feedManager.articleCount(for: feed) > displayLimit
    }

    private var filteredArticles: [Article] {
        var articles = feedManager.articles(for: feed, limit: displayLimit)
        if hideReels && feed.isInstagramFeed {
            articles = articles.filter { !$0.url.contains("/reel/") }
        }
        return articles
    }

    var body: some View {
        ArticlesView(
            articles: filteredArticles,
            title: currentFeed.title,
            feedKey: String(feed.id),
            isVideoFeed: feed.isVideoFeed,
            isPodcastFeed: feed.isPodcast,
            isInstagramFeed: feed.isInstagramFeed,
            isFeedViewDomain: feed.isFeedViewDomain,
            isTimelineViewDomain: feed.isTimelineViewDomain,
            onLoadMore: hasMore ? {
                displayLimit += Self.pageSize
            } : nil,
            onRefresh: { [feed] in
                try? await feedManager.refreshFeed(feed)
            },
            onMarkAllRead: {
                feedManager.markAllRead(feed: feed)
            }
        )
        .refreshable {
            try? await feedManager.refreshFeed(feed)
        }
        .safeAreaInset(edge: .bottom, alignment: .leading, spacing: 0) {
            if markAllReadPosition == .bottom {
                ArticlesToolbar {
                    feedManager.markAllRead(feed: feed)
                }
            }
        }
    }
}
