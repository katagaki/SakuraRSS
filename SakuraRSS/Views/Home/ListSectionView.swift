import SwiftUI

struct ListSectionView: View {

    @Environment(FeedManager.self) var feedManager

    let list: FeedList

    @AppStorage("Articles.BatchingMode") private var batchingMode: BatchingMode = .day1
    @State private var loadedSinceDate: Date = BatchingMode.current().initialSinceDate()
    @State private var loadedCount: Int = BatchingMode.current().initialCount()
    @AppStorage("Display.MarkAllReadPosition") private var markAllReadPosition: MarkAllReadPosition = .bottom
    @AppStorage("Articles.HideViewedContent") private var hideViewedContent: Bool = false
    @State private var visibleArticleIDs: Set<Int64>?

    private var rawArticles: [Article] {
        if batchingMode.isCountBased {
            return feedManager.articles(for: list, limit: loadedCount)
        }
        return feedManager.articles(for: list, since: loadedSinceDate)
    }

    private var displayedArticles: [Article] {
        let articles = rawArticles
        if hideViewedContent, let visibleArticleIDs {
            return articles.filter { visibleArticleIDs.contains($0.id) }
        }
        return articles
    }

    private func captureVisibleSnapshot() {
        guard hideViewedContent else {
            visibleArticleIDs = nil
            return
        }
        visibleArticleIDs = Set(rawArticles.filter { !$0.isRead }.map(\.id))
    }

    private func extendVisibleSnapshot() {
        guard hideViewedContent else {
            visibleArticleIDs = nil
            return
        }
        let unreadIDs = Set(rawArticles.filter { !$0.isRead }.map(\.id))
        visibleArticleIDs = (visibleArticleIDs ?? []).union(unreadIDs)
    }

    private func performRefresh() async {
        captureVisibleSnapshot()
        await feedManager.refreshAllFeeds()
        extendVisibleSnapshot()
    }

    private var loadMoreAction: (() -> Void)? {
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
            articles: displayedArticles,
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
            await performRefresh()
        }
        .markAllReadToolbar(show: markAllReadPosition == .bottom) {
            feedManager.markAllRead(for: list)
        }
        .task {
            if visibleArticleIDs == nil {
                captureVisibleSnapshot()
            }
        }
        .onChange(of: batchingMode) { _, newMode in
            loadedSinceDate = newMode.initialSinceDate()
            loadedCount = newMode.initialCount()
            captureVisibleSnapshot()
        }
        .onChange(of: loadedSinceDate) { _, _ in
            extendVisibleSnapshot()
        }
        .onChange(of: loadedCount) { _, _ in
            extendVisibleSnapshot()
        }
        .onChange(of: hideViewedContent) { _, newValue in
            if newValue {
                captureVisibleSnapshot()
            } else {
                visibleArticleIDs = nil
            }
        }
    }
}
