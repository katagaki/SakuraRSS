import SwiftUI

struct AllArticlesView: View {

    @Environment(FeedManager.self) var feedManager

    @State private var isShowingMarkAllReadConfirmation = false
    @State private var showingOlderArticles = false

    private var displayedArticles: [Article] {
        if showingOlderArticles {
            return feedManager.todayArticles() + feedManager.olderArticles()
        } else {
            return feedManager.todayArticles()
        }
    }

    var body: some View {
        ArticleListView(
            articles: displayedArticles,
            title: String(localized: "Shared.AllArticles"),
            feedKey: "all",
            onLoadMore: showingOlderArticles ? nil : {
                showingOlderArticles = true
            }
        )
        .refreshable {
            await feedManager.refreshAllFeeds()
        }
        .safeAreaInset(edge: .bottom, alignment: .leading, spacing: 0) {
            FeedToolbar {
                feedManager.markAllRead()
            }
        }
    }
}
