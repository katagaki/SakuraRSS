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
    let showsLastUpdated: Bool
    let effectiveStyleBinding: Binding<FeedDisplayStyle?>?
    var leadingHeader: AnyView?

    init(
        source: HomeContentSource,
        showsListHeader: Bool = false,
        showsLastUpdated: Bool = true,
        effectiveStyleBinding: Binding<FeedDisplayStyle?>? = nil,
        leadingHeader: AnyView? = nil
    ) {
        self.source = source
        self.showsListHeader = showsListHeader
        self.showsLastUpdated = showsLastUpdated
        self.effectiveStyleBinding = effectiveStyleBinding
        self.leadingHeader = leadingHeader
    }

    init(section: FeedSection?) {
        self.source = .section(section)
        self.showsListHeader = false
        self.showsLastUpdated = true
        self.effectiveStyleBinding = nil
    }

    init(
        list: FeedList,
        showsListHeader: Bool = false,
        showsLastUpdated: Bool = true,
        effectiveStyleBinding: Binding<FeedDisplayStyle?>? = nil
    ) {
        self.source = .list(list)
        self.showsListHeader = showsListHeader
        self.showsLastUpdated = showsLastUpdated
        self.effectiveStyleBinding = effectiveStyleBinding
    }

    init(topic: String) {
        self.source = .topic(topic)
        self.showsListHeader = false
        self.showsLastUpdated = true
        self.effectiveStyleBinding = nil
    }

    @AppStorage("Articles.BatchingMode") private var storedBatchingMode: BatchingMode = .items25
    @AppStorage(DoomscrollingMode.storageKey) private var doomscrollingMode: Bool = false
    @State private var loadedSinceDate: Date = Date(timeIntervalSince1970: 0)
    @State private var loadedCount: Int = BatchingMode.current().initialCount()
    @State private var hasInitializedSinceDate = false
    @State var preloadedEntries: [ArticleIDEntry] = []
    @AppStorage("Instagram.HideReels") private var hideInstagramReels: Bool = false
    @State var visibility = ArticleVisibilityTracker()
    @State private var scrollToTopTick: Int = 0
    @State private var loadMoreTarget: LoadMoreTarget?
    @State var lastLoadedSource: HomeContentSource?
    @State private var lastLoadedHideViewed: Bool?
    @State private var fetchedArticles: [Article] = []
    @State private var hasLoadedWindow = false

    private var batchingMode: BatchingMode {
        DoomscrollingMode.effectiveBatchingMode(storedBatchingMode)
    }

    var hideViewedContent: Bool {
        feedManager.hidesReadContent(onPage: pageKey)
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

    private func assembleArticles(_ windowed: [Article]) -> [Article] {
        guard hideInstagramReels else { return windowed }
        return windowed.filter { !$0.url.contains("/reel/") }
    }

    /// Live assembly that performs the database fetch; used for the initial
    /// frame and the visibility-capture sites that need a current snapshot.
    func currentRawArticles() -> [Article] {
        assembleArticles(feedManager.articles(withPreloadedIDs: slicedIDs))
    }

    /// Cached assembly read by `body` and the visibility trackers, so
    /// scroll-driven re-evaluations don't hit the database.
    var rawArticles: [Article] {
        guard hasLoadedWindow else { return currentRawArticles() }
        return assembleArticles(fetchedArticles)
    }

    func refreshWindowedArticles() {
        refreshLoadMoreTarget()
        fetchedArticles = feedManager.articles(withPreloadedIDs: slicedIDs)
        hasLoadedWindow = true
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

    var loadMoreAction: (() -> Void)? {
        if hideViewedContent && visibility.hasReachedEnd { return nil }
        switch loadMoreTarget {
        case .sinceDate(let date): return { loadedSinceDate = date }
        case .count(let count): return { loadedCount = count }
        case nil: return nil
        }
    }

    var body: some View {
        let shownArticles = visibility.filter(rawArticles, isEnabled: hideViewedContent)
        ArticlesView(
            articles: shownArticles,
            title: title,
            feedKey: feedKey,
            isVideoFeed: isVideoSection,
            isPodcastFeed: isPodcastSection,
            isFeedViewDomain: isFeedViewSection,
            onLoadMore: loadMoreAction,
            onRefresh: { await performRefresh() },
            onMarkAllRead: performMarkAllRead,
            hideReadContent: feedManager.hideReadContentBinding(onPage: pageKey),
            scrollToTopTrigger: scrollToTopTick,
            headerView: headerView,
            effectiveStyleBinding: effectiveStyleBinding
        )
        .refreshable { [source] in
            startRefreshWithoutBlocking(source: source)
        }
        .hideReadContentPrompt(
            isVisible: visibility.containsReadContent(shownArticles, isRead: feedManager.isRead)
        ) {
            Task { await hideShownReadContent() }
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
            let sourceChanged = lastLoadedSource != source
            let hideViewedChanged = lastLoadedHideViewed != hideViewedContent
            let isFreshLoad = sourceChanged || hideViewedChanged || !hasInitializedSinceDate
            await reloadPreloadedEntries(keepingShownContent: !isFreshLoad)
            if Task.isCancelled { return }
            if isFreshLoad {
                loadedSinceDate = batchingMode.initialSinceDate(
                    latestArticleDate: latestArticleDate()
                )
                loadedCount = batchingMode.initialCount()
                visibility.capture(from: currentRawArticles(), isEnabled: hideViewedContent)
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
            refreshWindowedArticles()
            visibility.capture(from: currentRawArticles(), isEnabled: hideViewedContent)
        }
        .onChange(of: doomscrollingMode) { _, _ in
            visibility.capture(from: currentRawArticles(), isEnabled: hideViewedContent)
        }
        .onChange(of: loadedCount) { _, _ in
            refreshWindowedArticles()
        }
        .onChange(of: loadedSinceDate) { _, _ in
            refreshWindowedArticles()
        }
    }

}

extension HomeSectionView {
    /// Latest preloaded entry date, so the initial batch anchors on visible content.
    func latestArticleDate() -> Date? {
        preloadedEntries.compactMap(\.publishedDate).max()
    }

    func hideShownReadContent() async {
        feedManager.flushDebouncedReads()
        await reloadPreloadedEntries()
        loadedSinceDate = batchingMode.initialSinceDate(latestArticleDate: latestArticleDate())
        loadedCount = batchingMode.initialCount()
        refreshWindowedArticles()
        withAnimation(.smooth.speed(2.0)) {
            visibility.capture(from: currentRawArticles(), isEnabled: hideViewedContent, isRead: feedManager.isRead)
        }
        scrollToTopTick &+= 1
    }

    func acceptPendingRefresh() {
        withAnimation(.smooth.speed(2.0)) {
            visibility.acceptPendingRefresh()
        }
        scrollToTopTick &+= 1
    }

}

private struct PreloadKey: Hashable {
    let source: HomeContentSource
    let revision: Int
    let hideViewed: Bool
}
