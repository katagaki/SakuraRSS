import SwiftUI

struct HomeSectionView: View {

    @Environment(FeedManager.self) var feedManager

    let section: FeedSection

    @AppStorage("Articles.BatchingMode") private var batchingMode: BatchingMode = .day1
    @State private var loadedSinceDate: Date = BatchingMode.current().initialSinceDate()
    @State private var loadedCount: Int = BatchingMode.current().initialCount()
    @AppStorage("Display.MarkAllReadPosition") private var markAllReadPosition: MarkAllReadPosition = .bottom
    @AppStorage("Instagram.HideReels") private var hideInstagramReels: Bool = false
    @AppStorage("Articles.HideViewedContent") private var hideViewedContent: Bool = false
    @State private var visibility = ArticleVisibilityTracker()

    private var rawArticles: [Article] {
        var articles: [Article]
        if batchingMode.isCountBased {
            articles = feedManager.articles(for: section, limit: loadedCount)
        } else {
            articles = feedManager.articles(for: section, since: loadedSinceDate)
        }
        if hideInstagramReels {
            articles = articles.filter { !$0.url.contains("/reel/") }
        }
        return articles
    }

    private func performRefresh() async {
        feedManager.flushDebouncedReads()
        visibility.capture(from: rawArticles, isEnabled: hideViewedContent)
        await feedManager.refreshAllFeeds()
        visibility.extend(from: rawArticles, isEnabled: hideViewedContent)
    }

    /// Kicks off a refresh and returns immediately so SwiftUI dismisses the
    /// pull-to-refresh indicator; in-flight progress shows via the toolbar donut.
    private func startRefreshWithoutBlocking() {
        feedManager.flushDebouncedReads()
        visibility.capture(from: rawArticles, isEnabled: hideViewedContent)
        Task { @MainActor in
            await feedManager.refreshAllFeeds()
            visibility.extend(from: rawArticles, isEnabled: hideViewedContent)
        }
    }

    private var loadMoreAction: (() -> Void)? {
        if hideViewedContent && visibility.hasReachedEnd { return nil }
        if let days = batchingMode.chunkDays {
            guard let next = feedManager.nextArticleChunk(for: section,
                                                          before: loadedSinceDate,
                                                          chunkDays: days) else {
                return nil
            }
            return { loadedSinceDate = next }
        }
        if let batch = batchingMode.batchSize {
            guard feedManager.hasMoreArticles(for: section, beyond: loadedCount) else { return nil }
            return { loadedCount += batch }
        }
        return nil
    }

    var body: some View {
        ArticlesView(
            articles: visibility.filter(rawArticles, isEnabled: hideViewedContent),
            title: section.localizedTitle,
            feedKey: "home.\(section.rawValue)",
            isVideoFeed: section == .video,
            isPodcastFeed: section == .audio,
            isFeedViewDomain: section == .social,
            onLoadMore: loadMoreAction,
            onRefresh: {
                await performRefresh()
            },
            onMarkAllRead: {
                feedManager.markAllRead(for: section)
            }
        )
        .refreshable {
            startRefreshWithoutBlocking()
        }
        .markAllReadToolbar(show: markAllReadPosition == .bottom) {
            feedManager.markAllRead(for: section)
        }
        .trackArticleVisibility(
            $visibility,
            hideViewedContent: hideViewedContent,
            loadedSinceDate: loadedSinceDate,
            loadedCount: loadedCount,
            rawArticles: { rawArticles }
        )
        .onChange(of: batchingMode) { _, newMode in
            loadedSinceDate = newMode.initialSinceDate()
            loadedCount = newMode.initialCount()
            visibility.capture(from: rawArticles, isEnabled: hideViewedContent)
        }
    }
}
