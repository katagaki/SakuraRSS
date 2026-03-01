import SwiftUI

struct AllArticlesView: View {

    @Environment(FeedManager.self) var feedManager

    var body: some View {
        ArticleListView(
            articles: feedManager.articles,
            title: String(localized: "Shared.AllArticles")
        )
        .refreshable {
            await feedManager.refreshAllFeeds()
        }
    }
}
