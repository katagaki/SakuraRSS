import SwiftUI

struct ListSectionView: View {

    @Environment(FeedManager.self) var feedManager

    let list: FeedList

    @AppStorage("Articles.BatchingMode") private var batchingMode: BatchingMode = .day1
    @State private var loadedSinceDate: Date = BatchingMode.current().initialSinceDate()
    @State private var loadedCount: Int = BatchingMode.current().initialCount()
    @AppStorage("Display.MarkAllReadPosition") private var markAllReadPosition: MarkAllReadPosition = .bottom
    @AppStorage("Articles.HideViewedContent") private var hideViewedContent: Bool = false
    @State private var visibility = ArticleVisibilityTracker()

    private var rawArticles: [Article] {
        if batchingMode.isCountBased {
            return feedManager.articles(for: list, limit: loadedCount)
        }
        return feedManager.articles(for: list, since: loadedSinceDate)
    }

    private func performRefresh() async {
        feedManager.flushDebouncedReads()
        visibility.beginRefresh(from: rawArticles, isEnabled: hideViewedContent)
        await feedManager.refreshAllFeeds()
        withAnimation(.smooth.speed(2.0)) {
            visibility.endRefresh(from: rawArticles, isEnabled: hideViewedContent)
        }
    }

    /// Kicks off a refresh and returns immediately so SwiftUI dismisses the
    /// pull-to-refresh indicator; in-flight progress shows via the toolbar donut.
    private func startRefreshWithoutBlocking() {
        feedManager.flushDebouncedReads()
        visibility.beginRefresh(from: rawArticles, isEnabled: hideViewedContent)
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
    }

    private var loadMoreAction: (() -> Void)? {
        if hideViewedContent && visibility.hasReachedEnd { return nil }
        if let days = batchingMode.chunkDays {
            guard let next = feedManager.nextArticleChunk(for: list,
                                                          before: loadedSinceDate,
                                                          chunkDays: days) else {
                return nil
            }
            return { loadedSinceDate = next }
        }
        if let batch = batchingMode.batchSize {
            guard feedManager.hasMoreArticles(for: list, beyond: loadedCount) else { return nil }
            return { loadedCount += batch }
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
            }
        )
        .refreshable {
            startRefreshWithoutBlocking()
        }
        .markAllReadToolbar(show: markAllReadPosition == .bottom) {
            feedManager.markAllRead(for: list)
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
        .onChange(of: batchingMode) { _, newMode in
            loadedSinceDate = newMode.initialSinceDate()
            loadedCount = newMode.initialCount()
            visibility.capture(from: rawArticles, isEnabled: hideViewedContent)
        }
    }
}
