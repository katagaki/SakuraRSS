import SwiftUI

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

    init(source: HomeContentSource) {
        self.source = source
    }

    init(section: FeedSection?) {
        self.source = .section(section)
    }

    init(list: FeedList) {
        self.source = .list(list)
    }

    init(topic: String) {
        self.source = .topic(topic)
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

    @AppStorage("WhileYouSlept.DismissedDate") private var whileYouSleptDismissedDate: String = ""
    @AppStorage("TodaysSummary.DismissedDate") private var todaysSummaryDismissedDate: String = ""
    @State private var whileYouSleptAvailable = false
    @State private var todaysSummaryAvailable = false

    private var batchingMode: BatchingMode {
        DoomscrollingMode.effectiveBatchingMode(storedBatchingMode)
    }

    private var hideViewedContent: Bool {
        DoomscrollingMode.effectiveHideViewedContent(storedHideViewedContent)
    }

    private var batcher: ArticleIDBatcher {
        ArticleIDBatcher(entries: preloadedEntries)
    }

    private var section: FeedSection? {
        if case .section(let section) = source { return section }
        return nil
    }

    private var list: FeedList? {
        if case .list(let list) = source { return list }
        return nil
    }

    private var isAllFollowing: Bool {
        if case .section(nil) = source { return true }
        return false
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
        var articles: [Article]
        if let section {
            articles = feedManager.undatedArticles(for: section)
                + feedManager.articles(withPreloadedIDs: slicedIDs)
        } else {
            articles = feedManager.articles(withPreloadedIDs: slicedIDs)
        }
        if hideInstagramReels {
            articles = articles.filter { !$0.url.contains("/reel/") }
        }
        return articles
    }

    private func reloadPreloadedEntries() {
        switch source {
        case .section(let section):
            if let section {
                preloadedEntries = feedManager.preloadedArticleEntries(
                    for: section,
                    requireUnread: hideViewedContent
                )
            } else {
                preloadedEntries = feedManager.preloadedArticleEntries(
                    requireUnread: hideViewedContent
                )
            }
        case .list(let list):
            preloadedEntries = feedManager.preloadedArticleEntries(
                for: list,
                requireUnread: hideViewedContent
            )
        case .topic(let name):
            preloadedEntries = feedManager.preloadedArticleEntries(
                forTopic: name,
                requireUnread: hideViewedContent
            )
        }
        if hideViewedContent, visibility.visibleIDs == nil, !preloadedEntries.isEmpty {
            visibility.capture(from: rawArticles, isEnabled: hideViewedContent)
        }
    }

    private func performRefresh() async {
        guard !scopedRefreshState.hasActiveProgress else { return }
        feedManager.flushDebouncedReads()
        withAnimation(.smooth.speed(2.0)) {
            visibility.beginRefresh(
                from: rawArticles,
                isEnabled: hideViewedContent,
                recaptureVisible: true
            )
        }
        await feedManager.refreshFeeds(scope: scopeKey, feeds: scopedFeeds)
        withAnimation(.smooth.speed(2.0)) {
            visibility.endRefresh(from: rawArticles, isEnabled: hideViewedContent)
        }
    }

    /// Kicks off a refresh and returns immediately so SwiftUI dismisses the
    /// pull-to-refresh indicator; in-flight progress shows via the toolbar donut.
    private func startRefreshWithoutBlocking() {
        guard !scopedRefreshState.hasActiveProgress else { return }
        feedManager.flushDebouncedReads()
        withAnimation(.smooth.speed(2.0)) {
            visibility.beginRefresh(
                from: rawArticles,
                isEnabled: hideViewedContent,
                recaptureVisible: true
            )
        }
        let scope = scopeKey
        let feeds = scopedFeeds
        Task { @MainActor in
            await feedManager.refreshFeeds(scope: scope, feeds: feeds)
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

    private var isPodcastSection: Bool {
        section == .podcasts
    }

    private var title: String {
        switch source {
        case .section(let section):
            return section?.localizedTitle ?? HomeSection.all.localizedTitle
        case .list(let list):
            return list.name
        case .topic(let name):
            return name
        }
    }

    private var feedKey: String {
        switch source {
        case .section(let section):
            if let section { return "home.\(section.rawValue)" }
            return "all"
        case .list(let list):
            return "list.\(list.id)"
        case .topic(let name):
            return "topic.\(name)"
        }
    }

    private var scopeKey: String {
        switch source {
        case .section(let section):
            if let section { return "section.\(section.rawValue)" }
            return "section.all"
        case .list(let list):
            return "list.\(list.id)"
        case .topic(let name):
            return "topic.\(name)"
        }
    }

    private var scopedFeeds: [Feed] {
        switch source {
        case .section(let section):
            guard let section else { return feedManager.feeds }
            return feedManager.feeds.filter { $0.feedSection == section }
        case .list(let list):
            return feedManager.feeds(for: list)
        case .topic:
            return feedManager.feeds
        }
    }

    private var scopedRefreshState: ScopedRefreshState {
        feedManager.scopedRefreshes[scopeKey] ?? ScopedRefreshState()
    }

    private var todayDateKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private var anySummaryHidden: Bool {
        guard isAllFollowing else { return false }
        return (whileYouSleptDismissedDate == todayDateKey && whileYouSleptAvailable)
            || (todaysSummaryDismissedDate == todayDateKey && todaysSummaryAvailable)
    }

    private func performMarkAllRead() {
        switch source {
        case .section(let section):
            if let section {
                feedManager.markAllRead(for: section)
            } else {
                feedManager.markAllRead()
            }
        case .list(let list):
            feedManager.markAllRead(for: list)
        case .topic:
            for article in rawArticles where !feedManager.isRead(article) {
                feedManager.markRead(article)
            }
        }
    }

    var body: some View {
        ArticlesView(
            articles: visibility.filter(rawArticles, isEnabled: hideViewedContent),
            title: title,
            feedKey: feedKey,
            isVideoFeed: isVideoSection,
            isPodcastFeed: isPodcastSection,
            isFeedViewDomain: isFeedViewSection,
            anySummaryHidden: anySummaryHidden,
            onRestoreSummaries: isAllFollowing ? {
                withAnimation(.smooth.speed(2.0)) {
                    whileYouSleptDismissedDate = ""
                    todaysSummaryDismissedDate = ""
                }
            } : nil,
            onLoadMore: loadMoreAction,
            onRefresh: { await performRefresh() },
            onMarkAllRead: performMarkAllRead,
            scrollToTopTrigger: scrollToTopTick,
            additionalLeadingToolbar: scopedRefreshState.hasActiveProgress ? AnyView(
                FeedRefreshProgressDonut(
                    progress: scopedRefreshState.progress,
                    onStop: { [scope = scopeKey] in feedManager.cancelScopedRefresh(scope: scope) }
                )
            ) : nil
        )
        .safeAreaInset(edge: .top, spacing: 0) {
            if isAllFollowing {
                VStack(spacing: 0) {
                    WhileYouSleptView(hasSummary: $whileYouSleptAvailable)
                    TodaysSummaryView(hasSummary: $todaysSummaryAvailable)
                }
                .animation(.smooth.speed(2.0), value: whileYouSleptDismissedDate)
                .animation(.smooth.speed(2.0), value: todaysSummaryDismissedDate)
                .padding(.bottom, 8)
            }
        }
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
                    latestArticleDate: latestArticleDate()
                )
                hasInitializedSinceDate = true
            }
        }
        .onChange(of: source) { _, _ in
            reloadPreloadedEntries()
            loadedSinceDate = batchingMode.initialSinceDate(
                latestArticleDate: latestArticleDate()
            )
            loadedCount = batchingMode.initialCount()
            visibility.capture(from: rawArticles, isEnabled: hideViewedContent)
        }
        .onChange(of: feedManager.dataRevision) { _, _ in
            reloadPreloadedEntries()
        }
        .onChange(of: hideViewedContent) { _, _ in
            reloadPreloadedEntries()
            loadedSinceDate = batchingMode.initialSinceDate(
                latestArticleDate: latestArticleDate()
            )
            loadedCount = batchingMode.initialCount()
            visibility.capture(from: rawArticles, isEnabled: hideViewedContent)
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

    /// Latest preloaded entry date, so the initial batch anchors on visible content.
    private func latestArticleDate() -> Date? {
        preloadedEntries.compactMap(\.publishedDate).max()
    }
}
