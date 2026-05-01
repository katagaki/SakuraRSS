import SwiftUI

struct GridStyleView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.zoomNamespace) private var zoomNamespace
    let articles: [Article]
    var onLoadMore: (() -> Void)?
    var headerView: AnyView?

    private var articlesWithImages: [Article] {
        articles.filter { $0.imageURL != nil }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 12) {
                if let headerView {
                    headerView
                }
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(articlesWithImages) { article in
                        ArticleLink(article: article, label: {
                            GridArticleCell(article: article)
                                .zoomSource(id: article.id, namespace: zoomNamespace)
                                .markReadOnScroll(article: article)
                        })
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                feedManager.toggleRead(article)
                            } label: {
                                Label(
                                    feedManager.isRead(article)
                                        ? String(localized: "Article.MarkUnread", table: "Articles")
                                        : String(localized: "Article.MarkRead", table: "Articles"),
                                    systemImage: feedManager.isRead(article)
                                        ? "envelope" : "envelope.open"
                                )
                            }
                            Divider()
                            if let shareURL = URL(string: article.url) {
                                ShareLink(item: shareURL) {
                                    Label(String(localized: "Article.Share", table: "Articles"),
                                          systemImage: "square.and.arrow.up")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.top, headerView == nil ? 12 : 0)
                if let onLoadMore {
                    LoadPreviousArticlesButton(action: onLoadMore, articleCount: articles.count)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
            }
            .padding(.bottom)
        }
        .trackScrollActivity()
    }
}
