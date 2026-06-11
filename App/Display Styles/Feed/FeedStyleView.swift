import SwiftUI
import Hanami

struct FeedStyleView: View {

    @Environment(FeedManager.self) var feedManager
    #if targetEnvironment(macCatalyst)
    @Environment(\.openWindow) private var openWindow
    #endif
    @Environment(\.zoomNamespace) private var zoomNamespace
    let articles: [Article]
    var variant: FeedStyleVariant = .full
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
                ZStack {
                    ArticleLink(article: article, label: {
                        EmptyView()
                    })
                    .opacity(0)

                    rowContent(for: article)
                }
                .padding(.horizontal, 12)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0))
                .listRowSeparator(.hidden, edges: .top)
                .listRowSeparator(.visible, edges: .bottom)
                .alignmentGuide(.listRowSeparatorLeading) { _ in
                    return 0
                }
                .alignmentGuide(.listRowSeparatorTrailing) { dimensions in
                    return dimensions.width
                }
                .contextMenu {
                    rowContextMenu(for: article)
                }
            }
            if let onLoadMore {
                LoadPreviousArticlesButton(action: onLoadMore, articleCount: articles.count)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .trackScrollActivity()
    }

    private var stackLayout: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                if let headerView {
                    headerView
                }
                ForEach(articles) { article in
                    ArticleLink(article: article, label: {
                        rowContent(for: article)
                            .contentShape(.rect)
                    })
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .contextMenu {
                        rowContextMenu(for: article)
                    }
                    // Lazy containers reuse the context menu interaction, which can
                    // present the previously long-pressed item's menu without an
                    // explicit identity.
                    .id(article.id)
                    Divider()
                }
                if let onLoadMore {
                    LoadPreviousArticlesButton(action: onLoadMore, articleCount: articles.count)
                }
            }
        }
        .trackScrollActivity()
    }

    private func rowContent(for article: Article) -> some View {
        Group {
            if variant == .compact {
                CompactFeedArticleRow(article: article)
            } else {
                FeedArticleRow(article: article)
            }
        }
        .zoomSource(id: article.id, namespace: zoomNamespace)
        .markReadOnScroll(article: article)
    }

    @ViewBuilder
    private func rowContextMenu(for article: Article) -> some View {
        #if targetEnvironment(macCatalyst)
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
        #endif
        MoveToFolderMenuItems(article: article)
    }
}
