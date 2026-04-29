import SwiftUI

struct FeedArticlesView: View {

    @Environment(FeedManager.self) var feedManager
    let feed: Feed

    @AppStorage("Articles.BatchingMode") private var storedBatchingMode: BatchingMode = .items25
    @AppStorage(DoomscrollingMode.storageKey) private var doomscrollingMode: Bool = false
    @State private var loadedSinceDate: Date = Date(timeIntervalSince1970: 0)
    @State private var loadedCount: Int = BatchingMode.current().initialCount()
    @State private var hasInitializedSinceDate = false
    @State private var preloadedEntries: [ArticleIDEntry] = []
    @AppStorage("Instagram.HideReels") private var hideReels: Bool = false
    @AppStorage("Articles.HideViewedContent") private var storedHideViewedContent: Bool = false
    @State private var visibility = ArticleVisibilityTracker()
    @State private var scrollToTopTick: Int = 0

    private var batchingMode: BatchingMode {
        DoomscrollingMode.effectiveBatchingMode(storedBatchingMode)
    }

    private var hideViewedContent: Bool {
        DoomscrollingMode.effectiveHideViewedContent(storedHideViewedContent)
    }

    private var currentFeed: Feed {
        feedManager.feeds.first(where: { $0.id == feed.id }) ?? feed
    }

    private var batcher: ArticleIDBatcher {
        ArticleIDBatcher(entries: preloadedEntries)
    }

    private var loadMoreAction: (() -> Void)? {
        if hideViewedContent && visibility.hasReachedEnd { return nil }
        let batcher = self.batcher
        if let days = batchingMode.chunkDays {
            guard let next = batcher.nextChunkStart(before: loadedSinceDate, chunkDays: days) else {
                return nil
            }
            return { loadedSinceDate = next }
        }
        if let batch = batchingMode.batchSize {
            guard let next = batcher.nextLoadedCount(after: loadedCount, batchSize: batch) else {
                return nil
            }
            return { loadedCount = next }
        }
        return nil
    }

    private var rawArticles: [Article] {
        let batcher = self.batcher
        let slicedIDs: [Int64]
        if batchingMode.isCountBased {
            slicedIDs = batcher.ids(limit: loadedCount)
        } else if batchingMode.isDateBased {
            slicedIDs = batcher.ids(since: loadedSinceDate)
        } else {
            slicedIDs = preloadedEntries.map(\.id)
        }
        var articles = feedManager.undatedArticles(for: feed)
            + feedManager.articles(withPreloadedIDs: slicedIDs)
        if hideReels && feed.isInstagramFeed {
            articles = articles.filter { !$0.url.contains("/reel/") }
        }
        return articles
    }

    private func reloadPreloadedEntries() {
        preloadedEntries = feedManager.preloadedArticleEntries(
            for: feed,
            requireUnread: hideViewedContent
        )
    }

    private func performRefresh() async {
        log("FeedArticlesView", "performRefresh id=\(feed.id) title=\(feed.title) isLoading=\(feedManager.isLoading)")
        guard !feedManager.isLoading else { return }
        feedManager.flushDebouncedReads()
        withAnimation(.smooth.speed(2.0)) {
            visibility.beginRefresh(from: rawArticles, isEnabled: hideViewedContent)
        }
        try? await feedManager.refreshFeed(feed)
        withAnimation(.smooth.speed(2.0)) {
            visibility.endRefresh(from: rawArticles, isEnabled: hideViewedContent)
        }
        log("FeedArticlesView", "performRefresh end id=\(feed.id)")
    }

    private func acceptPendingRefresh() {
        withAnimation(.smooth.speed(2.0)) {
            visibility.acceptPendingRefresh()
        }
        scrollToTopTick &+= 1
    }

    var body: some View {
        ArticlesView(
            articles: visibility.filter(rawArticles, isEnabled: hideViewedContent),
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
            },
            scrollToTopTrigger: scrollToTopTick
        )
        .refreshable {
            log("FeedArticlesView", ".refreshable triggered id=\(feed.id)")
            await performRefresh()
        }
        .trackArticleVisibility(
            $visibility,
            hideViewedContent: hideViewedContent,
            loadedSinceDate: loadedSinceDate,
            loadedCount: loadedCount,
            rawArticles: { rawArticles }
        )
        .trackBackgroundRefresh(
            $visibility,
            isLoading: feedManager.isLoading,
            hideViewedContent: hideViewedContent,
            rawArticles: { rawArticles }
        )
        .refreshPromptOverlay(isVisible: visibility.hasPendingRefresh) {
            acceptPendingRefresh()
        }
        .onAppear {
            // swiftlint:disable:next line_length
            log("FeedArticlesView", "onAppear id=\(feed.id) title=\(feed.title) hasInitializedSinceDate=\(hasInitializedSinceDate)")
            reloadPreloadedEntries()
            if !hasInitializedSinceDate {
                loadedSinceDate = batchingMode.initialSinceDate(
                    latestArticleDate: latestArticleDateForFeed()
                )
                hasInitializedSinceDate = true
            }
        }
        .onChange(of: feed.id) { _, _ in
            reloadPreloadedEntries()
            loadedSinceDate = batchingMode.initialSinceDate(
                latestArticleDate: latestArticleDateForFeed()
            )
            loadedCount = batchingMode.initialCount()
            visibility.capture(from: rawArticles, isEnabled: hideViewedContent)
        }
        .onChange(of: feedManager.dataRevision) { _, _ in
            reloadPreloadedEntries()
        }
        .onChange(of: hideViewedContent) { _, _ in
            reloadPreloadedEntries()
        }
        .onChange(of: batchingMode) { _, newMode in
            loadedSinceDate = newMode.initialSinceDate(
                latestArticleDate: latestArticleDateForFeed()
            )
            loadedCount = newMode.initialCount()
            visibility.capture(from: rawArticles, isEnabled: hideViewedContent)
        }
        .onChange(of: doomscrollingMode) { _, _ in
            visibility.capture(from: rawArticles, isEnabled: hideViewedContent)
        }
    }

    /// Most recent published date for this feed, used to anchor the initial
    /// date-based batch so feeds that haven't posted in a while still surface
    /// their newest content rather than showing an empty state.
    private func latestArticleDateForFeed() -> Date? {
        feedManager.latestPublishedDate(forFeedIDs: [feed.id])
    }
}
