import SwiftUI

struct HomeSectionView: View {

    @Environment(FeedManager.self) var feedManager

    let section: FeedSection

    @AppStorage("Articles.BatchingMode") private var storedBatchingMode: BatchingMode = .items25
    @AppStorage(DoomscrollingMode.storageKey) private var doomscrollingMode: Bool = false
    @State private var loadedSinceDate: Date = Date(timeIntervalSince1970: 0)
    @State private var loadedCount: Int = BatchingMode.current().initialCount()
    @State private var hasInitializedSinceDate = false
    @State private var preloadedEntries: [ArticleIDEntry] = []
    @AppStorage("Instagram.HideReels") private var hideInstagramReels: Bool = false
    @AppStorage("Articles.HideViewedContent") private var storedHideViewedContent: Bool = false
    @State private var visibility = ArticleVisibilityTracker()
    @State private var scrollToTopTick: Int = 0

    private var batchingMode: BatchingMode {
        DoomscrollingMode.effectiveBatchingMode(storedBatchingMode)
    }

    private var hideViewedContent: Bool {
        DoomscrollingMode.effectiveHideViewedContent(storedHideViewedContent)
    }

    private var batcher: ArticleIDBatcher {
        ArticleIDBatcher(entries: preloadedEntries)
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
        var articles = feedManager.undatedArticles(for: section)
            + feedManager.articles(withPreloadedIDs: slicedIDs)
        if hideInstagramReels {
            articles = articles.filter { !$0.url.contains("/reel/") }
        }
        return articles
    }

    private func reloadPreloadedEntries() {
        preloadedEntries = feedManager.preloadedArticleEntries(
            for: section,
            requireUnread: hideViewedContent
        )
    }

    private func performRefresh() async {
        guard !feedManager.isLoading else { return }
        feedManager.flushDebouncedReads()
        withAnimation(.smooth.speed(2.0)) {
            visibility.beginRefresh(
                from: rawArticles,
                isEnabled: hideViewedContent,
                recaptureVisible: true
            )
        }
        await feedManager.refreshAllFeeds()
        withAnimation(.smooth.speed(2.0)) {
            visibility.endRefresh(from: rawArticles, isEnabled: hideViewedContent)
        }
    }

    /// Kicks off a refresh and returns immediately so SwiftUI dismisses the
    /// pull-to-refresh indicator; in-flight progress shows via the toolbar donut.
    private func startRefreshWithoutBlocking() {
        guard !feedManager.isLoading else { return }
        feedManager.flushDebouncedReads()
        withAnimation(.smooth.speed(2.0)) {
            visibility.beginRefresh(
                from: rawArticles,
                isEnabled: hideViewedContent,
                recaptureVisible: true
            )
        }
        Task { @MainActor in
            await feedManager.refreshAllFeeds()
            withAnimation(.smooth.speed(2.0)) {
                visibility.endRefresh(from: rawArticles, isEnabled: hideViewedContent)
            }
        }
    }

    private func acceptPendingRefresh() {
        withAnimation(.smooth.speed(2.0)) {
            visibility.acceptPendingRefresh()
        }
        scrollToTopTick &+= 1
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

    private var isVideoSection: Bool {
        section == .youtube || section == .vimeo || section == .niconico
    }

    private var isFeedViewSection: Bool {
        section == .x || section == .mastodon || section == .bluesky
    }

    var body: some View {
        ArticlesView(
            articles: visibility.filter(rawArticles, isEnabled: hideViewedContent),
            title: section.localizedTitle,
            feedKey: "home.\(section.rawValue)",
            isVideoFeed: isVideoSection,
            isPodcastFeed: section == .podcasts,
            isFeedViewDomain: isFeedViewSection,
            onLoadMore: loadMoreAction,
            onRefresh: {
                await performRefresh()
            },
            onMarkAllRead: {
                feedManager.markAllRead(for: section)
            },
            scrollToTopTrigger: scrollToTopTick
        )
        .refreshable {
            startRefreshWithoutBlocking()
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
            reloadPreloadedEntries()
            if !hasInitializedSinceDate {
                loadedSinceDate = batchingMode.initialSinceDate(
                    latestArticleDate: latestArticleDateForSection()
                )
                hasInitializedSinceDate = true
            }
        }
        .onChange(of: section) { _, _ in
            reloadPreloadedEntries()
            loadedSinceDate = batchingMode.initialSinceDate(
                latestArticleDate: latestArticleDateForSection()
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
                latestArticleDate: latestArticleDateForSection()
            )
            loadedCount = newMode.initialCount()
            visibility.capture(from: rawArticles, isEnabled: hideViewedContent)
        }
        .onChange(of: doomscrollingMode) { _, _ in
            visibility.capture(from: rawArticles, isEnabled: hideViewedContent)
        }
    }

    private func latestArticleDateForSection() -> Date? {
        let sectionFeedIDs = Set(
            feedManager.feeds.filter { $0.feedSection == section }.map(\.id)
        )
        guard !sectionFeedIDs.isEmpty else { return nil }
        return feedManager.latestPublishedDate(forFeedIDs: sectionFeedIDs)
    }
}
