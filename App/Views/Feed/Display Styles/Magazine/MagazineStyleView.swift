import SwiftUI

struct MagazineStyleView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.zoomNamespace) private var zoomNamespace
    let articles: [Article]
    var onLoadMore: (() -> Void)?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 12) {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(articles) { article in
                        ArticleLink(article: article, label: {
                            MagazineArticleCard(article: article)
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
                            Button {
                                feedManager.toggleBookmark(article)
                            } label: {
                                Label(
                                    article.isBookmarked
                                        ? String(localized: "Article.RemoveBookmark", table: "Articles")
                                        : String(localized: "Article.Bookmark", table: "Articles"),
                                    systemImage: article.isBookmarked
                                        ? "bookmark.fill" : "bookmark"
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                if let onLoadMore {
                    LoadPreviousArticlesButton(action: onLoadMore, articleCount: articles.count)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.bottom)
        }
        .animation(.smooth.speed(2.0), value: articles)
        .trackScrollActivity()
    }
}
