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
