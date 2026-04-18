import SwiftUI

struct FeedArticlesView: View {

    @Environment(FeedManager.self) var feedManager
    let feed: Feed

    @AppStorage("Articles.BatchingMode") private var batchingMode: BatchingMode = .day1
    @State private var loadedSinceDate: Date = BatchingMode.current().initialSinceDate()
    @State private var loadedCount: Int = BatchingMode.current().initialCount()
    @AppStorage("Display.MarkAllReadPosition") private var markAllReadPosition: MarkAllReadPosition = .bottom
    @AppStorage("Instagram.HideReels") private var hideReels: Bool = false

    private var currentFeed: Feed {
        feedManager.feeds.first(where: { $0.id == feed.id }) ?? feed
    }

    private var loadMoreAction: (() -> Void)? {
        if let days = batchingMode.chunkDays {
            guard let next = feedManager.nextArticleChunk(for: feed,
                                                          before: loadedSinceDate,
                                                          chunkDays: days) else {
                return nil
            }
            return { loadedSinceDate = next }
        }
        if let batch = batchingMode.batchSize {
            guard feedManager.hasMoreArticles(for: feed, beyond: loadedCount) else { return nil }
            return { loadedCount += batch }
        }
        return nil
    }

    private var filteredArticles: [Article] {
        var articles: [Article]
        if batchingMode.isCountBased {
            articles = feedManager.undatedArticles(for: feed)
                + feedManager.articles(for: feed, limit: loadedCount)
        } else {
            articles = feedManager.undatedArticles(for: feed)
                + feedManager.articles(for: feed, since: loadedSinceDate)
        }
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
            onLoadMore: loadMoreAction,
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
        .markAllReadToolbar(show: markAllReadPosition == .bottom) {
            feedManager.markAllRead(feed: feed)
        }
        .onChange(of: batchingMode) { _, newMode in
            loadedSinceDate = newMode.initialSinceDate()
            loadedCount = newMode.initialCount()
        }
    }
}
