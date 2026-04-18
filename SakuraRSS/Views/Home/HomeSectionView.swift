import SwiftUI

struct HomeSectionView: View {

    @Environment(FeedManager.self) var feedManager

    let section: FeedSection

    @AppStorage("Articles.BatchingMode") private var batchingMode: BatchingMode = .day1
    @State private var loadedSinceDate: Date = BatchingMode.current().initialSinceDate()
    @State private var loadedCount: Int = BatchingMode.current().initialCount()
    @AppStorage("Display.MarkAllReadPosition") private var markAllReadPosition: MarkAllReadPosition = .bottom
    @AppStorage("Instagram.HideReels") private var hideInstagramReels: Bool = false

    private var displayedArticles: [Article] {
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

    private var loadMoreAction: (() -> Void)? {
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
            articles: displayedArticles,
            title: section.localizedTitle,
            feedKey: "home.\(section.rawValue)",
            isVideoFeed: section == .video,
            isPodcastFeed: section == .audio,
            isFeedViewDomain: section == .social,
            onLoadMore: loadMoreAction,
            onRefresh: {
                await feedManager.refreshAllFeeds()
            },
            onMarkAllRead: {
                feedManager.markAllRead(for: section)
            }
        )
        .refreshable {
            await feedManager.refreshAllFeeds()
        }
        .markAllReadToolbar(show: markAllReadPosition == .bottom) {
            feedManager.markAllRead(for: section)
        }
        .onChange(of: batchingMode) { _, newMode in
            loadedSinceDate = newMode.initialSinceDate()
            loadedCount = newMode.initialCount()
        }
    }
}
