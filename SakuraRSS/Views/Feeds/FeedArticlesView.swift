import SwiftUI

struct FeedArticlesView: View {

    @Environment(FeedManager.self) var feedManager
    let feed: Feed
    @State private var isShowingMarkAllReadConfirmation = false

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
                Button {
                    isShowingMarkAllReadConfirmation = true
                } label: {
                    Image(systemName: "checkmark.circle")
                }
                .popover(isPresented: $isShowingMarkAllReadConfirmation) {
                    VStack(spacing: 12) {
                        Text(String(localized: "Articles.MarkAllRead.Confirm"))
                            .font(.subheadline)
                        Button(String(localized: "Articles.MarkAllRead")) {
                            feedManager.markAllRead(feed: feed)
                            isShowingMarkAllReadConfirmation = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .presentationCompactAdaptation(.popover)
                }
            }
        }
    }
}
