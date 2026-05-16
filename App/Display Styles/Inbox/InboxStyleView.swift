import SwiftUI
import Hanami

struct InboxStyleView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.zoomNamespace) private var zoomNamespace
    #if targetEnvironment(macCatalyst)
    @Environment(\.openWindow) private var openWindow
    #endif
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
                        Image(systemName: feedManager.isBookmarked(article) ? "bookmark.slash" : "bookmark")
                    }
                    .tint(.orange)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden, edges: .top)
                .listRowSeparator(.visible, edges: .bottom)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                #if targetEnvironment(macCatalyst)
                .contextMenu {
                    OpenInNewWindowButton(article: article)
                    Divider()
                    Button {
                        feedManager.toggleRead(article)
                    } label: {
                        Label(
                            feedManager.isRead(article)
                                ? String(localized: "Article.MarkUnread", table: "Articles")
                                : String(localized: "Article.MarkRead", table: "Articles"),
                            systemImage: feedManager.isRead(article) ? "envelope" : "envelope.open"
                        )
                    }
                    Button {
                        feedManager.toggleBookmark(article)
                    } label: {
                        Label(
                            feedManager.isBookmarked(article)
                                ? String(localized: "Article.RemoveBookmark", table: "Articles")
                                : String(localized: "Article.Bookmark", table: "Articles"),
                            systemImage: feedManager.isBookmarked(article) ? "bookmark.fill" : "bookmark"
                        )
                    }
                }
                #endif
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
