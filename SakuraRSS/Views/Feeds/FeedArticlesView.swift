import SwiftUI

struct FeedArticlesView: View {

    @Environment(FeedManager.self) var feedManager
    let feed: Feed
    @State private var isShowingMarkAllReadConfirmation = false

    var body: some View {
        ArticleListView(
            articles: feedManager.articles(for: feed),
            title: feed.title,
            feedKey: String(feed.id),
            isYouTube: feed.isYouTube
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
                            .font(.body)
                        Button {
                            feedManager.markAllRead(feed: feed)
                            isShowingMarkAllReadConfirmation = false
                        } label: {
                            Text(String(localized: "Articles.MarkAllRead"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(20)
                    .presentationCompactAdaptation(.popover)
                }
            }
        }
    }
}
