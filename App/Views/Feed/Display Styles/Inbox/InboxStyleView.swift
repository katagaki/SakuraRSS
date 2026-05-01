import SwiftUI

struct InboxStyleView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.zoomNamespace) private var zoomNamespace
    let articles: [Article]
    var onLoadMore: (() -> Void)?
    var headerView: AnyView?

    var body: some View {
        List {
            if let headerView {
                headerView
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
            }
            ForEach(articles) { article in
                ArticleLink(article: article, label: {
                    InboxArticleRow(article: article)
                        .zoomSource(id: article.id, namespace: zoomNamespace)
                        .markReadOnScroll(article: article)
                })
                .swipeActions(edge: .leading) {
                    Button {
                        withAnimation(.smooth.speed(2.0)) {
                            feedManager.toggleRead(article)
                        }
                    } label: {
                        Image(systemName: feedManager.isRead(article) ? "envelope" : "envelope.open")
                    }
                    .tint(.blue)
                }
                .swipeActions(edge: .trailing) {
                    Button {
                        withAnimation(.smooth.speed(2.0)) {
                            feedManager.toggleBookmark(article)
                        }
                    } label: {
                        Image(systemName: article.isBookmarked ? "bookmark.slash" : "bookmark")
                    }
                    .tint(.orange)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden, edges: .top)
                .listRowSeparator(.visible, edges: .bottom)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            }
            if let onLoadMore {
                LoadPreviousArticlesButton(action: onLoadMore, articleCount: articles.count)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .trackScrollActivity()
        .navigationLinkIndicatorVisibility(.hidden)
    }
}
