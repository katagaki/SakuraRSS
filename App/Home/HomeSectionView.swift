import SwiftUI
import Hanami

/// Source of articles for `HomeSectionView`. Modeling section, list, and topic
/// together keeps the view type stable across selection changes so safeAreaInset
/// content (the Today tab bar) doesn't get torn down when switching modes.
enum HomeContentSource: Hashable {
    case section(FeedSection?)
    case list(FeedList)
    case topic(String)
}

struct HomeSectionView: View {

    @Environment(FeedManager.self) var feedManager

    let source: HomeContentSource
    let showsListHeader: Bool
    let effectiveStyleBinding: Binding<FeedDisplayStyle?>?
    let externalScrollToTopTrigger: Int

    init(
        source: HomeContentSource,
        showsListHeader: Bool = false,
        effectiveStyleBinding: Binding<FeedDisplayStyle?>? = nil,
        externalScrollToTopTrigger: Int = 0
    ) {
        self.source = source
        self.showsListHeader = showsListHeader
        self.effectiveStyleBinding = effectiveStyleBinding
        self.externalScrollToTopTrigger = externalScrollToTopTrigger
    }

    init(section: FeedSection?) {
        self.source = .section(section)
        self.showsListHeader = false
        self.effectiveStyleBinding = nil
        self.externalScrollToTopTrigger = 0
    }

    init(
        list: FeedList,
        showsListHeader: Bool = false,
        effectiveStyleBinding: Binding<FeedDisplayStyle?>? = nil,
        externalScrollToTopTrigger: Int = 0
    ) {
        self.source = .list(list)
        self.showsListHeader = showsListHeader
        self.effectiveStyleBinding = effectiveStyleBinding
        self.externalScrollToTopTrigger = externalScrollToTopTrigger
    }

    init(topic: String) {
        self.source = .topic(topic)
        self.showsListHeader = false
        self.effectiveStyleBinding = nil
        self.externalScrollToTopTrigger = 0
    }

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
    @State private var lastLoadedSource: HomeContentSource?
    @State private var lastLoadedHideViewed: Bool?

    private var batchingMode: BatchingMode {
        DoomscrollingMode.effectiveBatchingMode(storedBatchingMode)
    }

    private var hideViewedContent: Bool {
        DoomscrollingMode.effectiveHideViewedContent(storedHideViewedContent)
    }

    private var batcher: ArticleIDBatcher {
        ArticleIDBatcher(entries: preloadedEntries)
    }

    var section: FeedSection? {
        if case .section(let section) = source { return section }
        return nil
    }

    var list: FeedList? {
        if case .list(let list) = source { return list }
        return nil
    }

    var rawArticles: [Article] {
        let batcher = self.batcher
        let slicedIDs: [Int64]
        if batchingMode.isCountBased {
            slicedIDs = batcher.ids(limit: loadedCount)
        } else if batchingMode.isDateBased {
            slicedIDs = batcher.ids(since: loadedSinceDate)
        } else {
            slicedIDs = preloadedEntries.map(\.id)
        }
        var articles = feedManager.articles(withPreloadedIDs: slicedIDs)
        if hideInstagramReels {
            articles = articles.filter { !$0.url.contains("/reel/") }
        }
        return articles
    }

    private func reloadPreloadedEntries() async {
        let entries: [ArticleIDEntry]
        switch source {
        case .section(let section):
            if let section {
                entries = await feedManager.preloadedArticleEntriesAsync(
                    for: section,
                    requireUnread: hideViewedContent
                )
            } else {
                entries = await feedManager.preloadedArticleEntriesAsync(
                    requireUnread: hideViewedContent
                )
            }
        case .list(let list):
            entries = await feedManager.preloadedArticleEntriesAsync(
                for: list,
                requireUnread: hideViewedContent
            )
        case .topic(let name):
            entries = await feedManager.preloadedArticleEntriesAsync(
                forTopic: name,
                requireUnread: hideViewedContent
            )
        }
        if Task.isCancelled { return }
        if entries.isEmpty,
           !preloadedEntries.isEmpty,
           lastLoadedSource == source {
            return
        }
        preloadedEntries = entries
        if hideViewedContent, visibility.visibleIDs == nil, !preloadedEntries.isEmpty {
            visibility.capture(from: rawArticles, isEnabled: hideViewedContent)
        }
    }

    private func performRefresh() async {
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
        await feedManager.refreshFeeds(scope: scopeKey, feeds: scopedFeeds)
        await reloadPreloadedEntries()
        withAnimation(.smooth.speed(2.0)) {
            visibility.endRefresh(from: rawArticles, isEnabled: hideViewedContent)
        }
    }

    /// Kicks off a refresh and returns immediately so SwiftUI dismisses the
    /// pull-to-refresh indicator; in-flight progress shows via the toolbar donut.
    /// Scope and feeds are passed in rather than read from `self` so a stale
    /// `.refreshable` closure captured before a section switch can't kick off
    /// the previous section's refresh.
    private func startRefreshWithoutBlocking(scope: String, feeds: [Feed]) {
        let activeScopedState = feedManager.scopedRefreshes[scope] ?? ScopedRefreshState()
        guard !activeScopedState.hasActiveProgress,
              !feedManager.hasActiveRefreshProgress else { return }
        feedManager.flushDebouncedReads()
        withAnimation(.smooth.speed(2.0)) {
            visibility.beginRefresh(
                from: rawArticles,
                isEnabled: hideViewedContent,
                recaptureVisible: true
            )
        }
        Task { @MainActor in
            await feedManager.refreshFeeds(scope: scope, feeds: feeds)
            await reloadPreloadedEntries()
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

    var body: some View {
        ArticlesView(
            articles: visibility.filter(rawArticles, isEnabled: hideViewedContent),
            title: title,
            feedKey: feedKey,
            isVideoFeed: isVideoSection,
            isPodcastFeed: isPodcastSection,
            isFeedViewDomain: isFeedViewSection,
            onLoadMore: loadMoreAction,
            onRefresh: { await performRefresh() },
            onMarkAllRead: performMarkAllRead,
            scrollToTopTrigger: scrollToTopTick &+ externalScrollToTopTrigger,
            headerView: headerView,
            effectiveStyleBinding: effectiveStyleBinding
        )
        .refreshable { [scope = scopeKey, feeds = scopedFeeds] in
            startRefreshWithoutBlocking(scope: scope, feeds: feeds)
        }
        .id(source)
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
        .task(id: PreloadKey(
            source: source,
            revision: feedManager.dataRevision,
            hideViewed: hideViewedContent
        )) {
            let priorSource = lastLoadedSource
            let priorHideViewed = lastLoadedHideViewed
            await reloadPreloadedEntries()
            if Task.isCancelled { return }
            let sourceChanged = priorSource != source
            let hideViewedChanged = priorHideViewed != hideViewedContent
            if sourceChanged || hideViewedChanged || !hasInitializedSinceDate {
                loadedSinceDate = batchingMode.initialSinceDate(
                    latestArticleDate: latestArticleDate()
                )
                loadedCount = batchingMode.initialCount()
                visibility.capture(from: rawArticles, isEnabled: hideViewedContent)
                hasInitializedSinceDate = true
            }
            lastLoadedSource = source
            lastLoadedHideViewed = hideViewedContent
        }
        .onChange(of: batchingMode) { _, newMode in
            loadedSinceDate = newMode.initialSinceDate(
                latestArticleDate: latestArticleDate()
            )
            loadedCount = newMode.initialCount()
            visibility.capture(from: rawArticles, isEnabled: hideViewedContent)
        }
        .onChange(of: doomscrollingMode) { _, _ in
            visibility.capture(from: rawArticles, isEnabled: hideViewedContent)
        }
    }

}

extension HomeSectionView {
    /// Latest preloaded entry date, so the initial batch anchors on visible content.
    func latestArticleDate() -> Date? {
        preloadedEntries.compactMap(\.publishedDate).max()
    }
}

private struct PreloadKey: Hashable {
    let source: HomeContentSource
    let revision: Int
    let hideViewed: Bool
}
