import SwiftUI

struct HomeSectionView: View {

    @Environment(FeedManager.self) var feedManager

    let section: FeedSection

    @State private var loadedSinceDate: Date = FeedManager.currentChunkStart()
    @AppStorage("Display.MarkAllReadPosition") private var markAllReadPosition: MarkAllReadPosition = .bottom
    @AppStorage("Instagram.HideReels") private var hideInstagramReels: Bool = false

    private var displayedArticles: [Article] {
        var articles = feedManager.articles(for: section, since: loadedSinceDate)
        if hideInstagramReels {
            articles = articles.filter { !$0.url.contains("/reel/") }
        }
        return articles
    }

    private var nextOlderChunk: Date? {
        feedManager.nextArticleChunk(for: section, before: loadedSinceDate)
    }

    var body: some View {
        ArticlesView(
            articles: displayedArticles,
            title: section.localizedTitle,
            feedKey: "home.\(section.rawValue)",
            isVideoFeed: section == .video,
            isPodcastFeed: section == .audio,
            isFeedViewDomain: section == .social,
            onLoadMore: nextOlderChunk.map { chunk in
                { loadedSinceDate = chunk }
            },
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
    }
}
