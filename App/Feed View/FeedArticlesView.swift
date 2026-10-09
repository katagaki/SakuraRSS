import SwiftUI
import Hanami

struct FeedArticlesView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.isBrowserChromeActive) var isBrowserChromeActive
    @Environment(\.dismiss) var dismiss
    let feed: Feed

    @AppStorage("Articles.BatchingMode") private var storedBatchingMode: BatchingMode = .items25
    @AppStorage(DoomscrollingMode.storageKey) private var doomscrollingMode: Bool = false
    @State private var loadedSinceDate: Date = Date(timeIntervalSince1970: 0)
    @State private var loadedCount: Int = BatchingMode.current().initialCount()
    @State private var hasInitializedSinceDate = false
    @State private var preloadedEntries: [ArticleIDEntry] = []
    @AppStorage("Instagram.HideReels") private var hideReels: Bool = false
    @State private var visibility = ArticleVisibilityTracker()
    @State var scrollToTopTick: Int = 0
    @State var hasScrolledPastTitle: Bool = false
    @State var effectiveDisplayStyle: FeedDisplayStyle?
    @State private var prominentColors: [Color] = []
    @State private var fetchedArticles: [Article] = []
    @State private var undatedTail: [Article] = []
    @State private var hasLoadedWindow = false
    @State private var loadMoreTarget: LoadMoreTarget?
    @State private var lastLoadedFeedID: Int64?
    @State private var lastLoadedHideViewed: Bool?

    private var batchingMode: BatchingMode {
        DoomscrollingMode.effectiveBatchingMode(storedBatchingMode)
    }

    private var pageKey: String {
        feedManager.pageKey(for: currentFeed)
    }

    private var hideViewedContent: Bool {
        feedManager.hidesReadContent(onPage: pageKey)
    }

    var currentFeed: Feed {
        feedManager.feedsByID[feed.id] ?? feed
    }

    private var feedExists: Bool {
        feedManager.feedsByID[feed.id] != nil
    }

    private var scopeKey: String { "feed.\(feed.id)" }

    var scopedRefreshState: ScopedRefreshState {
        feedManager.scopedRefreshes[scopeKey] ?? ScopedRefreshState()
    }

    private var batcher: ArticleIDBatcher {
        ArticleIDBatcher(entries: preloadedEntries)
    }

    private var loadMoreAction: (() -> Void)? {
        if hideViewedContent && visibility.hasReachedEnd { return nil }
        switch loadMoreTarget {
        case .sinceDate(let date): return { loadedSinceDate = date }
        case .count(let count): return { loadedCount = count }
        case nil: return nil
        }
    }

    private func refreshLoadMoreTarget() {
        let batcher = self.batcher
        if let days = batchingMode.chunkDays {
            loadMoreTarget = batcher
                .nextChunkStart(before: loadedSinceDate, chunkDays: days)
                .map(LoadMoreTarget.sinceDate)
        } else if let batch = batchingMode.batchSize {
            loadMoreTarget = batcher
                .nextLoadedCount(after: loadedCount, batchSize: batch)
                .map(LoadMoreTarget.count)
        } else {
            loadMoreTarget = nil
        }
    }

    private var slicedIDs: [Int64] {
        let batcher = self.batcher
        if batchingMode.isCountBased {
            return batcher.ids(limit: loadedCount)
        } else if batchingMode.isDateBased {
            return batcher.ids(since: loadedSinceDate)
        } else {
            return preloadedEntries.map(\.id)
        }
    }

    private func assembleArticles(windowed: [Article], undated: [Article]) -> [Article] {
        var articles = windowed
        if loadMoreAction == nil {
            articles += undated
        }
        if hideReels && feed.isInstagramFeed {
            articles = articles.filter { !$0.url.contains("/reel/") }
        }
        return articles
    }

    /// Live assembly that performs the database fetches; used for the initial
    /// frame and the visibility-capture sites that need a current snapshot.
    private func currentRawArticles() -> [Article] {
        assembleArticles(
            windowed: feedManager.articles(withPreloadedIDs: slicedIDs),
            undated: feedManager.undatedArticles(for: feed)
        )
    }

    /// Cached assembly read by `body` and the visibility trackers, so
    /// scroll-driven re-evaluations don't hit the database.
    private var rawArticles: [Article] {
        guard hasLoadedWindow else { return currentRawArticles() }
        return assembleArticles(windowed: fetchedArticles, undated: undatedTail)
    }

    private func refreshWindowedArticles() {
        refreshLoadMoreTarget()
        fetchedArticles = feedManager.articles(withPreloadedIDs: slicedIDs)
        hasLoadedWindow = true
    }

    private func refreshUndatedTail() {
        undatedTail = feedManager.undatedArticles(for: feed)
    }

    var body: some View {
        let shownArticles = visibility.filter(rawArticles, isEnabled: hideViewedContent)
        ArticlesView(
            articles: shownArticles,
            title: currentFeed.title,
            subtitle: nil,
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
            hideReadContent: feedManager.hideReadContentBinding(onPage: pageKey),
            scrollToTopTrigger: scrollToTopTick,
            headerView: AnyView(
                FeedHeaderView(feed: currentFeed)
            ),
            additionalLeadingToolbar: scopedRefreshState.hasActiveProgress ? AnyView(
                FeedRefreshProgressDonut(
                    progress: scopedRefreshState.progress,
                    isStopping: scopedRefreshState.isStopping,
                    onStop: { [scope = scopeKey] in feedManager.cancelScopedRefresh(scope: scope) }
                )
            ) : nil,
            effectiveStyleBinding: $effectiveDisplayStyle
        )
        .environment(\.feedBackgroundColors, prominentColors)
        .toolbar {
            principalTitleItem
        }
        .onScrollGeometryChange(for: Bool.self) { geo in
            geo.contentOffset.y > 90
        } action: { _, scrolled in
            guard scrolled != hasScrolledPastTitle else { return }
            withAnimation(.smooth.speed(2.0)) {
                hasScrolledPastTitle = scrolled
            }
        }
        .animation(.smooth.speed(2.0), value: styleSupportsRichHeader)
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
        .hideReadContentPrompt(
            isVisible: visibility.containsReadContent(shownArticles, isRead: feedManager.isRead)
        ) {
            Task { await hideShownReadContent() }
        }
        .task(id: feed.id) {
            await loadProminentColors()
        }
        .onChange(of: feedManager.iconRevision) {
            Task { await loadProminentColors() }
        }
        .task(id: FeedPreloadKey(
            feedID: feed.id,
            revision: feedManager.dataRevision,
            hideViewed: hideViewedContent
        )) {
            let feedChanged = lastLoadedFeedID != feed.id
            let hideViewedChanged = lastLoadedHideViewed != hideViewedContent
            let isFreshLoad = feedChanged || hideViewedChanged || !hasInitializedSinceDate
            await reloadPreloadedEntries(keepingShownContent: !isFreshLoad)
            if Task.isCancelled { return }
            if isFreshLoad {
                loadedSinceDate = batchingMode.initialSinceDate(
                    latestArticleDate: latestArticleDateForFeed()
                )
                loadedCount = batchingMode.initialCount()
                visibility.capture(from: currentRawArticles(), isEnabled: hideViewedContent)
                hasInitializedSinceDate = true
            }
            lastLoadedFeedID = feed.id
            lastLoadedHideViewed = hideViewedContent
        }
        .onChange(of: loadedCount) { _, _ in
            refreshWindowedArticles()
        }
        .onChange(of: loadedSinceDate) { _, _ in
            refreshWindowedArticles()
        }
        .onChange(of: batchingMode) { _, newMode in
            loadedSinceDate = newMode.initialSinceDate(
                latestArticleDate: latestArticleDateForFeed()
            )
            loadedCount = newMode.initialCount()
            refreshWindowedArticles()
            visibility.capture(from: currentRawArticles(), isEnabled: hideViewedContent)
        }
        .onChange(of: doomscrollingMode) { _, _ in
            visibility.capture(from: currentRawArticles(), isEnabled: hideViewedContent)
        }
        .onChange(of: feedExists) { _, exists in
            if !exists { dismiss() }
        }
    }

}

extension FeedArticlesView {

    func reloadPreloadedEntries(keepingShownContent: Bool = false) async {
        let entries = await feedManager.preloadedArticleEntriesAsync(
            for: feed,
            requireUnread: hideViewedContent
        )
        if Task.isCancelled { return }
        if entries.isEmpty, !preloadedEntries.isEmpty, lastLoadedFeedID == feed.id {
            return
        }
        preloadedEntries = keepingShownContent
            ? visibility.keepingShownEntries(of: preloadedEntries, in: entries)
            : entries
        refreshWindowedArticles()
        refreshUndatedTail()
        if hideViewedContent, visibility.visibleIDs == nil, !preloadedEntries.isEmpty {
            visibility.capture(from: currentRawArticles(), isEnabled: hideViewedContent)
        }
    }

    func performRefresh() async {
        // swiftlint:disable:next line_length
        log("FeedArticlesView", "performRefresh id=\(feed.id) title=\(feed.title) scopeActive=\(scopedRefreshState.hasActiveProgress)")
        guard !scopedRefreshState.hasActiveProgress,
              !feedManager.hasActiveRefreshProgress else { return }
        feedManager.flushDebouncedReads()
        withAnimation(.smooth.speed(2.0)) {
            visibility.beginRefresh(
                from: rawArticles,
                isEnabled: hideViewedContent,
                recaptureVisible: true
            )
        }
        await feedManager.refreshFeeds(
            scope: scopeKey,
            feeds: [feed],
            skipImagePreload: false,
            runNLP: true
        )
        await reloadPreloadedEntries()
        withAnimation(.smooth.speed(2.0)) {
            visibility.endRefresh(from: rawArticles, isEnabled: hideViewedContent)
        }
        log("FeedArticlesView", "performRefresh end id=\(feed.id)")
    }

    func acceptPendingRefresh() {
        withAnimation(.smooth.speed(2.0)) {
            visibility.acceptPendingRefresh()
        }
        scrollToTopTick &+= 1
    }

    func hideShownReadContent() async {
        feedManager.flushDebouncedReads()
        await reloadPreloadedEntries()
        loadedSinceDate = batchingMode.initialSinceDate(latestArticleDate: latestArticleDateForFeed())
        loadedCount = batchingMode.initialCount()
        refreshWindowedArticles()
        withAnimation(.smooth.speed(2.0)) {
            visibility.capture(from: currentRawArticles(), isEnabled: hideViewedContent, isRead: feedManager.isRead)
        }
        scrollToTopTick &+= 1
    }

    func latestArticleDateForFeed() -> Date? {
        feedManager.latestPublishedDate(forFeedIDs: [feed.id])
    }

    func loadProminentColors() async {
        let image = await Iconography.shared.icon(for: currentFeed)
        let source: UIImage? = image ?? currentFeed.acronymIcon.flatMap { UIImage(data: $0) }
        prominentColors = source?.prominentColors ?? []
    }
}

private struct FeedPreloadKey: Hashable {
    let feedID: Int64
    let revision: Int
    let hideViewed: Bool
}
