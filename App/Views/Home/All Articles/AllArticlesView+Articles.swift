import SwiftUI

extension AllArticlesView {

    var batchingMode: BatchingMode {
        DoomscrollingMode.effectiveBatchingMode(storedBatchingMode)
    }

    var hideViewedContent: Bool {
        DoomscrollingMode.effectiveHideViewedContent(storedHideViewedContent)
    }

    var todayDateKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    var anySummaryHidden: Bool {
        (whileYouSleptDismissedDate == todayDateKey && whileYouSleptAvailable)
        || (todaysSummaryDismissedDate == todayDateKey && todaysSummaryAvailable)
    }

    var batcher: ArticleIDBatcher {
        ArticleIDBatcher(entries: preloadedEntries)
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

    var displayedArticles: [Article] {
        visibility.filter(rawArticles, isEnabled: hideViewedContent)
    }

    var currentTitle: String {
        switch selectedSelection {
        case .section(let section):
            return section.localizedTitle
        case .list(let id):
            return feedManager.lists.first { $0.id == id }?.name
                ?? String(localized: "Shared.AllArticles")
        }
    }

    var loadMoreAction: (() -> Void)? {
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

    func reloadPreloadedEntries() {
        preloadedEntries = feedManager.preloadedArticleEntries(
            requireUnread: hideViewedContent
        )
        if hideViewedContent, visibility.visibleIDs == nil, !preloadedEntries.isEmpty {
            visibility.capture(from: rawArticles, isEnabled: hideViewedContent)
        }
    }

    /// Latest preloaded entry date, so the initial batch anchors on visible content.
    func latestArticleDateAcrossFeeds() -> Date? {
        preloadedEntries.compactMap(\.publishedDate).max()
    }
}
