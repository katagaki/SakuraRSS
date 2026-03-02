import SwiftUI

struct AllArticlesView: View {

    @Environment(FeedManager.self) var feedManager
    @State private var isShowingMarkAllReadConfirmation = false

    var body: some View {
        ArticleListView(
            articles: feedManager.articles,
            title: String(localized: "Shared.AllArticles"),
            feedKey: "all"
        )
        .refreshable {
            await feedManager.refreshAllFeeds()
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
                            feedManager.markAllRead()
                            isShowingMarkAllReadConfirmation = false
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
