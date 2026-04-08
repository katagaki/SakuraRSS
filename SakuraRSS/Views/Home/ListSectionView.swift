import SwiftUI

struct ListSectionView: View {

    @Environment(FeedManager.self) var feedManager

    let list: FeedList

    @State private var showingOlderArticles = false
    @AppStorage("Display.MarkAllReadPosition") private var markAllReadPosition: MarkAllReadPosition = .bottom

    private var displayedArticles: [Article] {
        if showingOlderArticles {
            return feedManager.todayArticles(for: list) + feedManager.olderArticles(for: list)
        } else {
            return feedManager.todayArticles(for: list)
        }
    }

    var body: some View {
        ArticlesView(
            articles: displayedArticles,
            title: list.name,
            feedKey: "list.\(list.id)",
            onLoadMore: showingOlderArticles ? nil : {
                showingOlderArticles = true
            },
            onRefresh: {
                await feedManager.refreshAllFeeds()
            },
            onMarkAllRead: {
                feedManager.markAllRead(for: list)
            }
        )
        .refreshable {
            await feedManager.refreshAllFeeds()
        }
        .safeAreaInset(edge: .bottom, alignment: .leading, spacing: 0) {
            if markAllReadPosition == .bottom {
                ArticlesToolbar {
                    feedManager.markAllRead(for: list)
                }
            }
        }
    }
}
