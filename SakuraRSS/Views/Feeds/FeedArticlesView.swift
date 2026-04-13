import SwiftUI

struct FeedArticlesView: View {

    @Environment(FeedManager.self) var feedManager
    let feed: Feed

    @State private var loadedSinceDate: Date = FeedManager.currentChunkStart()
    @AppStorage("Display.MarkAllReadPosition") private var markAllReadPosition: MarkAllReadPosition = .bottom
    @AppStorage("Instagram.HideReels") private var hideReels: Bool = false

    private var currentFeed: Feed {
        feedManager.feeds.first(where: { $0.id == feed.id }) ?? feed
    }

    private var nextOlderChunk: Date? {
        feedManager.nextArticleChunk(for: feed, before: loadedSinceDate)
    }

    private var filteredArticles: [Article] {
        var articles = feedManager.undatedArticles(for: feed)
            + feedManager.articles(for: feed, since: loadedSinceDate)
        if hideReels && feed.isInstagramFeed {
            articles = articles.filter { !$0.url.contains("/reel/") }
        }
        return articles
    }

    var body: some View {
        ArticlesView(
            articles: filteredArticles,
            title: currentFeed.title,
            subtitle: currentFeed.domain,
            feedKey: String(feed.id),
            isVideoFeed: feed.isVideoFeed,
            isPodcastFeed: feed.isPodcast,
            isInstagramFeed: feed.isInstagramFeed,
            isFeedViewDomain: feed.isFeedViewDomain,
            isFeedCompactViewDomain: feed.isFeedCompactViewDomain,
            isTimelineViewDomain: feed.isTimelineViewDomain,
            onLoadMore: nextOlderChunk.map { chunk in
                { loadedSinceDate = chunk }
            },
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
