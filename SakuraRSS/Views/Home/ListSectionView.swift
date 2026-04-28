import SwiftUI

struct ListSectionView: View {

    @Environment(FeedManager.self) var feedManager

    let list: FeedList

    @AppStorage("Articles.BatchingMode") private var storedBatchingMode: BatchingMode = .items25
    @AppStorage(DoomscrollingMode.storageKey) private var doomscrollingMode: Bool = false
    @State private var loadedSinceDate: Date = Date(timeIntervalSince1970: 0)
    @State private var loadedCount: Int = BatchingMode.current().initialCount()
    @State private var hasInitializedSinceDate = false
    @AppStorage("Articles.HideViewedContent") private var storedHideViewedContent: Bool = false
    @State private var visibility = ArticleVisibilityTracker()
    @State private var scrollToTopTick: Int = 0

    private var batchingMode: BatchingMode {
        DoomscrollingMode.effectiveBatchingMode(storedBatchingMode)
    }

    private var hideViewedContent: Bool {
        DoomscrollingMode.effectiveHideViewedContent(storedHideViewedContent)
    }

    private var rawArticles: [Article] {
        if batchingMode.isCountBased {
            return feedManager.articles(
                for: list,
                limit: loadedCount,
                requireUnread: hideViewedContent
            )
        }
        return feedManager.articles(for: list, since: loadedSinceDate)
    }

    private func performRefresh() async {
        guard !feedManager.isLoading else { return }
        feedManager.flushDebouncedReads()
        withAnimation(.smooth.speed(2.0)) {
            visibility.beginRefresh(from: rawArticles, isEnabled: hideViewedContent)
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
            visibility.beginRefresh(from: rawArticles, isEnabled: hideViewedContent)
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
        if let days = batchingMode.chunkDays {
            guard let next = feedManager.nextArticleChunk(
                for: list,
                before: loadedSinceDate,
                chunkDays: days,
                requireUnread: hideViewedContent
            ) else {
                return nil
            }
            return { loadedSinceDate = next }
        }
        if let batch = batchingMode.batchSize {
            guard let next = feedManager.nextLoadedCount(
                for: list,
                after: loadedCount,
                batchSize: batch,
                requireUnread: hideViewedContent
            ) else {
                return nil
            }
            return { loadedCount = next }
        }
        return nil
    }

    var body: some View {
        ArticlesView(
            articles: visibility.filter(rawArticles, isEnabled: hideViewedContent),
            title: list.name,
            feedKey: "list.\(list.id)",
            onLoadMore: loadMoreAction,
            onRefresh: {
                await performRefresh()
            },
            onMarkAllRead: {
                feedManager.markAllRead(for: list)
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
            if !hasInitializedSinceDate {
                loadedSinceDate = batchingMode.initialSinceDate(
                    latestArticleDate: latestArticleDateForList()
                )
                hasInitializedSinceDate = true
            }
        }
        .onChange(of: batchingMode) { _, newMode in
            loadedSinceDate = newMode.initialSinceDate(
                latestArticleDate: latestArticleDateForList()
            )
            loadedCount = newMode.initialCount()
            visibility.capture(from: rawArticles, isEnabled: hideViewedContent)
        }
        .onChange(of: doomscrollingMode) { _, _ in
            visibility.capture(from: rawArticles, isEnabled: hideViewedContent)
        }
    }

    private func latestArticleDateForList() -> Date? {
        feedManager.latestPublishedDate(forFeedIDs: feedManager.feedIDs(for: list))
    }
}
