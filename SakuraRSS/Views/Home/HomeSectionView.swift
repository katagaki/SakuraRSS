import SwiftUI

struct HomeSectionView: View {

    @Environment(FeedManager.self) var feedManager

    let section: FeedSection

    @State private var showingOlderArticles = false
    @AppStorage("Display.MarkAllReadPosition") private var markAllReadPosition: MarkAllReadPosition = .bottom
    @AppStorage("Instagram.HideReels") private var hideInstagramReels: Bool = false

    private var displayedArticles: [Article] {
        var articles: [Article]
        if showingOlderArticles {
            articles = feedManager.todayArticles(for: section) + feedManager.olderArticles(for: section)
        } else {
            articles = feedManager.todayArticles(for: section)
        }
        if hideInstagramReels {
            articles = articles.filter { !$0.url.contains("/reel/") }
        }
        return articles
    }

    var body: some View {
        ArticlesView(
            articles: displayedArticles,
            title: section.localizedTitle,
            feedKey: "home.\(section.rawValue)",
            isVideoFeed: section == .video,
            isPodcastFeed: section == .audio,
            isFeedViewDomain: section == .social,
            onLoadMore: showingOlderArticles ? nil : {
                showingOlderArticles = true
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
        .safeAreaInset(edge: .bottom, alignment: .leading, spacing: 0) {
            if markAllReadPosition == .bottom {
                ArticlesToolbar {
                    feedManager.markAllRead(for: section)
                }
            }
        }
    }
}
