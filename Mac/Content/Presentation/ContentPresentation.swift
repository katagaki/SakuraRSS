import Foundation
import Hanami

/// The Browsing settings applied to a page's content, as iOS applies them:
/// Hide Read Content keeps only what was unread when the page opened, plus
/// what arrives while it's open, and batching reveals older content a batch
/// at a time. Doomscrolling Mode turns both off.
struct ContentPresentation {

    private var shownIDs: Set<Int64>?
    private var loadedCount = 0
    private var loadedSinceDate = Date.distantPast
    private(set) var settings = Settings(hidesViewedContent: false, batchingMode: BatchingMode.current())

    struct Settings: Equatable {
        let hidesViewedContent: Bool
        let batchingMode: BatchingMode

        @MainActor
        static func current(for location: BrowserLocation, in feedManager: FeedManager) -> Settings {
            Settings(
                hidesViewedContent: location.pageKey(in: feedManager)
                    .map(feedManager.hidesReadContent(onPage:)) ?? false,
                batchingMode: BatchingMode.current()
            )
        }
    }

    /// Starts over for a page that has just been opened.
    mutating func begin(with articles: [Article], isRead: (Article) -> Bool, settings: Settings) {
        self.settings = settings
        shownIDs = settings.hidesViewedContent ? Set(articles.filter { !isRead($0) }.map(\.id)) : nil
        loadedCount = settings.batchingMode.initialCount()
        loadedSinceDate = settings.batchingMode.initialSinceDate(
            latestArticleDate: articles.lazy.compactMap(\.publishedDate).max()
        )
    }

    /// Content that arrives while the page is open is shown, read or not later.
    mutating func absorb(_ articles: [Article], isRead: (Article) -> Bool) {
        guard shownIDs != nil else { return }
        shownIDs?.formUnion(articles.filter { !isRead($0) }.map(\.id))
    }

    func present(_ articles: [Article]) -> [Article] {
        let visible = shownIDs.map { shown in articles.filter { shown.contains($0.id) } } ?? articles
        let mode = settings.batchingMode
        if mode.isCountBased {
            return Array(visible.prefix(loadedCount))
        }
        if mode.isDateBased {
            let windowed = visible.filter { ($0.publishedDate ?? .distantPast) >= loadedSinceDate }
            let undated = canLoadMore(visible) ? [] : visible.filter { $0.publishedDate == nil }
            return windowed + undated
        }
        return visible
    }

    func canLoadMore(_ articles: [Article]) -> Bool {
        nextBatch(of: articles) != nil
    }

    mutating func loadMore(of articles: [Article]) {
        switch nextBatch(of: articles) {
        case .count(let count): loadedCount = count
        case .sinceDate(let date): loadedSinceDate = date
        case nil: break
        }
    }

    private enum Batch {
        case count(Int)
        case sinceDate(Date)
    }

    private func nextBatch(of articles: [Article]) -> Batch? {
        let visible = shownIDs.map { shown in articles.filter { shown.contains($0.id) } } ?? articles
        let batcher = ArticleIDBatcher(entries: visible.compactMap { article in
            article.publishedDate.map { ArticleIDEntry(id: article.id, publishedDate: $0) }
        })
        let mode = settings.batchingMode
        if let batchSize = mode.batchSize {
            guard visible.count > loadedCount else { return nil }
            return .count(min(loadedCount + batchSize, visible.count))
        }
        if let days = mode.chunkDays {
            return batcher.nextChunkStart(before: loadedSinceDate, chunkDays: days).map(Batch.sinceDate)
        }
        return nil
    }
}
