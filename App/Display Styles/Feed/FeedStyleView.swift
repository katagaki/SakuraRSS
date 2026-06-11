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

    var body: some View {
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
            if let onLoadMore {
                LoadPreviousArticlesButton(action: onLoadMore, articleCount: articles.count)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .trackScrollActivity()
    }
}
