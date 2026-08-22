import SwiftUI
import Hanami

extension HomeSectionView {

    func reloadPreloadedEntries() async {
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
        refreshWindowedArticles()
        if hideViewedContent, visibility.visibleIDs == nil, !preloadedEntries.isEmpty {
            visibility.capture(from: currentRawArticles(), isEnabled: hideViewedContent)
        }
    }

    func performRefresh() async {
        guard !scopedRefreshState.hasActiveProgress,
              !feedManager.hasActiveRefreshProgress else { return }
        feedManager.flushDebouncedReads()
        withAnimation(.smooth.speed(2.0)) {
            visibility.beginRefresh(
                from: currentRawArticles(),
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
    /// The source is passed in rather than read from `self` so a stale
    /// `.refreshable` closure captured before a section switch can't kick off
    /// the previous section's refresh.
    func startRefreshWithoutBlocking(source: HomeContentSource) {
        let scope = scopeKey(for: source)
        let feeds = scopedFeeds(for: source)
        let activeScopedState = feedManager.scopedRefreshes[scope] ?? ScopedRefreshState()
        guard !activeScopedState.hasActiveProgress,
              !feedManager.hasActiveRefreshProgress else { return }
        feedManager.flushDebouncedReads()
        withAnimation(.smooth.speed(2.0)) {
            visibility.beginRefresh(
                from: currentRawArticles(),
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
}
