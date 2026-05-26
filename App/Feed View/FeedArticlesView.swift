import SwiftUI
import Hanami

struct FeedArticlesView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.dismiss) var dismiss
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
    @State private var hasScrolledPastTitle: Bool = false
    @State private var effectiveDisplayStyle: FeedDisplayStyle?
    @State private var prominentColors: [Color] = []
    @State private var fetchedArticles: [Article] = []
    @State private var undatedTail: [Article] = []
    @State private var hasLoadedWindow = false

    private var batchingMode: BatchingMode {
        DoomscrollingMode.effectiveBatchingMode(storedBatchingMode)
    }

    private var hideViewedContent: Bool {
        DoomscrollingMode.effectiveHideViewedContent(storedHideViewedContent)
    }

    private var currentFeed: Feed {
        feedManager.feeds.first(where: { $0.id == feed.id }) ?? feed
    }

    private var feedExists: Bool {
        feedManager.feeds.contains(where: { $0.id == feed.id })
    }

    private var scopeKey: String { "feed.\(feed.id)" }

    private var scopedRefreshState: ScopedRefreshState {
        feedManager.scopedRefreshes[scopeKey] ?? ScopedRefreshState()
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

    /// Live assembly that performs the database fetches. Used for the initial
    /// frame and the infrequent `visibility.capture` sites that need an
    /// up-to-date snapshot before the cache-refresh handlers fire.
    private func currentRawArticles() -> [Article] {
        assembleArticles(
            windowed: feedManager.articles(withPreloadedIDs: slicedIDs),
            undated: feedManager.undatedArticles(for: feed)
        )
    }

    /// Cached assembly read by `body` and the visibility trackers. Once the
    /// window has loaded this reads only in-memory state, so scroll-driven body
    /// re-evaluations (e.g. the visibility tracker ticking) never hit the
    /// database.
    private var rawArticles: [Article] {
        guard hasLoadedWindow else { return currentRawArticles() }
        return assembleArticles(windowed: fetchedArticles, undated: undatedTail)
    }

    private func refreshWindowedArticles() {
        fetchedArticles = feedManager.articles(withPreloadedIDs: slicedIDs)
        hasLoadedWindow = true
    }

    private func refreshUndatedTail() {
        undatedTail = feedManager.undatedArticles(for: feed)
    }

    var styleSupportsRichHeader: Bool {
        effectiveDisplayStyle?.supportsRichHeader ?? true
    }

    var showsPrincipalTitle: Bool {
        !styleSupportsRichHeader || hasScrolledPastTitle
    }

    var body: some View {
        ArticlesView(
            articles: visibility.filter(rawArticles, isEnabled: hideViewedContent),
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
            ToolbarItem(placement: .principal) {
                #if os(visionOS)
                principalTitleContent
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(height: 42)
                    .contentShape(.rect)
                    .onTapGesture { scrollToTopTick &+= 1 }
                    .allowsHitTesting(showsPrincipalTitle)
                    .opacity(showsPrincipalTitle ? 1 : 0)
                    .animation(.smooth.speed(2.0), value: showsPrincipalTitle)
                #else
                principalTitleContent
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(height: 44)
                    .padding(.horizontal, 18)
                    .compatibleGlassEffect(in: .capsule, interactive: true)
                    .contentShape(.capsule)
                    .onTapGesture { scrollToTopTick &+= 1 }
                    .allowsHitTesting(showsPrincipalTitle)
                    .opacity(showsPrincipalTitle ? 1 : 0)
                    .animation(.smooth.speed(2.0), value: showsPrincipalTitle)
                #endif
            }
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
        .task(id: feed.id) {
            await loadProminentColors()
        }
        .onChange(of: feedManager.iconRevision) {
            Task { await loadProminentColors() }
        }
        .onChange(of: feed.id) { _, _ in
            reloadPreloadedEntries()
            loadedSinceDate = batchingMode.initialSinceDate(
                latestArticleDate: latestArticleDateForFeed()
            )
            loadedCount = batchingMode.initialCount()
            visibility.capture(from: currentRawArticles(), isEnabled: hideViewedContent)
        }
        .onChange(of: slicedIDs) { _, _ in
            refreshWindowedArticles()
        }
        .onChange(of: feedManager.dataRevision) { _, _ in
            reloadPreloadedEntries()
            refreshWindowedArticles()
            refreshUndatedTail()
        }
        .onChange(of: hideViewedContent) { _, _ in
            reloadPreloadedEntries()
        }
        .onChange(of: batchingMode) { _, newMode in
            loadedSinceDate = newMode.initialSinceDate(
                latestArticleDate: latestArticleDateForFeed()
            )
            loadedCount = newMode.initialCount()
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

    @ViewBuilder
    var principalTitleContent: some View {
        if scopedRefreshState.isStopping {
            Text(String(localized: "Refresh.Stopping", table: "Home"))
                .font(.subheadline)
                .fontWeight(.semibold)
        } else {
            #if os(visionOS)
            VStack(alignment: .leading, spacing: 0) {
                feedTitleAndDomain
            }
            #else
            VStack(spacing: 0) {
                feedTitleAndDomain
            }
            #endif
        }
    }

    @ViewBuilder
    private var feedTitleAndDomain: some View {
        Text(currentFeed.title)
            .font(.subheadline)
            .fontWeight(.semibold)
        if !currentFeed.domain.isEmpty {
            Text(currentFeed.domain)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    func reloadPreloadedEntries() {
        let entries = feedManager.preloadedArticleEntries(
            for: feed,
            requireUnread: hideViewedContent
        )
        if entries.isEmpty, !preloadedEntries.isEmpty {
            return
        }
        preloadedEntries = entries
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
        reloadPreloadedEntries()
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

    func latestArticleDateForFeed() -> Date? {
        feedManager.latestPublishedDate(forFeedIDs: [feed.id])
    }

    func loadProminentColors() async {
        let image = await Iconography.shared.icon(for: currentFeed)
        let source: UIImage? = image ?? currentFeed.acronymIcon.flatMap { UIImage(data: $0) }
        prominentColors = source?.prominentColors ?? []
    }
}
