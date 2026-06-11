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
    var usesStackLayout: Bool = false

    var body: some View {
        if usesStackLayout {
            stackLayout
        } else {
            listLayout
        }
    }

    private var listLayout: some View {
        List {
            if let headerView {
                headerView
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
            }
            ForEach(articles) { article in
                articleRow(article)
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
                .modifier(MoveToFolderSwipeActionModifier(article: article))
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

    private var stackLayout: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                if let headerView {
                    headerView
                }
                ForEach(articles) { article in
                    articleRow(article)
                        .buttonStyle(.plain)
                        .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        // Lazy containers reuse the context menu interaction, which can
                        // present the previously long-pressed item's menu without an
                        // explicit identity.
                        .id(article.id)
                    Divider()
                        .padding(.horizontal, 12)
                }
                if let onLoadMore {
                    LoadPreviousArticlesButton(action: onLoadMore, articleCount: articles.count)
                }
            }
        }
        .trackScrollActivity()
    }

    private func articleRow(_ article: Article) -> some View {
        ArticleLink(article: article, label: {
            InboxArticleRow(article: article)
                .zoomSource(id: article.id, namespace: zoomNamespace)
                .markReadOnScroll(article: article)
                .contentShape(.rect)
        })
        .contextMenu {
            #if targetEnvironment(macCatalyst)
            OpenInNewWindowButton(article: article)
            Divider()
            #endif
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
            MoveToFolderMenuItems(article: article)
        }
    }
}
