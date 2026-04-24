import SwiftUI

struct FeedArticlesView: View {

    @Environment(FeedManager.self) var feedManager
    let feed: Feed

    @AppStorage("Articles.BatchingMode") private var batchingMode: BatchingMode = .day1
    @State private var loadedSinceDate: Date = BatchingMode.current().initialSinceDate()
    @State private var loadedCount: Int = BatchingMode.current().initialCount()
    @AppStorage("Display.MarkAllReadPosition") private var markAllReadPosition: MarkAllReadPosition = .bottom
    @AppStorage("Instagram.HideReels") private var hideReels: Bool = false
    @AppStorage("Articles.HideViewedContent") private var hideViewedContent: Bool = false
    @State private var visibleArticleIDs: Set<Int64>?

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

    private var rawArticles: [Article] {
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

    private var filteredArticles: [Article] {
        let articles = rawArticles
        if hideViewedContent, let visibleArticleIDs {
            return articles.filter { visibleArticleIDs.contains($0.id) }
        }
        return articles
    }

    private func captureVisibleSnapshot() {
        guard hideViewedContent else {
            visibleArticleIDs = nil
            return
        }
        visibleArticleIDs = Set(rawArticles.filter { !$0.isRead }.map(\.id))
    }

    private func extendVisibleSnapshot() {
        guard hideViewedContent else {
            visibleArticleIDs = nil
            return
        }
        let unreadIDs = Set(rawArticles.filter { !$0.isRead }.map(\.id))
        visibleArticleIDs = (visibleArticleIDs ?? []).union(unreadIDs)
    }

    private func performRefresh() async {
        try? await feedManager.refreshFeed(feed)
        captureVisibleSnapshot()
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
            onRefresh: {
                await performRefresh()
            },
            onMarkAllRead: {
                feedManager.markAllRead(feed: feed)
            }
        )
        .refreshable {
            await performRefresh()
        }
        .markAllReadToolbar(show: markAllReadPosition == .bottom) {
            feedManager.markAllRead(feed: feed)
        }
        .task {
            if visibleArticleIDs == nil {
                captureVisibleSnapshot()
            }
        }
        .onChange(of: batchingMode) { _, newMode in
            loadedSinceDate = newMode.initialSinceDate()
            loadedCount = newMode.initialCount()
            captureVisibleSnapshot()
        }
        .onChange(of: loadedSinceDate) { _, _ in
            extendVisibleSnapshot()
        }
        .onChange(of: loadedCount) { _, _ in
            extendVisibleSnapshot()
        }
        .onChange(of: hideViewedContent) { _, newValue in
            if newValue {
                captureVisibleSnapshot()
            } else {
                visibleArticleIDs = nil
            }
        }
    }
}
