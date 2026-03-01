import SwiftUI

struct FeedArticlesView: View {

    @Environment(FeedManager.self) var feedManager
    let feed: Feed

    var body: some View {
        ArticleListView(
            articles: feedManager.articles(for: feed),
            title: feed.title
        )
        .refreshable {
            try? await feedManager.refreshFeed(feed)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button {
                        feedManager.markAllRead(feed: feed)
                    } label: {
                        Label(String(localized: "Articles.MarkAllRead"),
                              systemImage: "checkmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
    }
}
