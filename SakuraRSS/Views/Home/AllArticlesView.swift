import SwiftUI

struct AllArticlesView: View {

    @Environment(FeedManager.self) var feedManager
    var body: some View {
        ArticleListView(
            articles: feedManager.articles,
            title: String(localized: "Shared.AllArticles"),
            feedKey: "all"
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
