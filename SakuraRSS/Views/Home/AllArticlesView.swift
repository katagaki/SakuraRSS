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
            ToolbarItemGroup(placement: .topBarLeading) {
                Button {
                    isShowingMarkAllReadConfirmation = true
                } label: {
                    Image(systemName: "checkmark.circle")
                }
                .popover(isPresented: $isShowingMarkAllReadConfirmation) {
                    VStack(spacing: 12) {
                        Text(String(localized: "Articles.MarkAllRead.Confirm"))
                            .font(.subheadline)
                        Button {
                            feedManager.markAllRead()
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
