import SwiftUI

struct MasonryStyleView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.zoomNamespace) private var zoomNamespace
    let articles: [Article]
    var onLoadMore: (() -> Void)?
    var headerView: AnyView?

    private static let columnCount = 2
    private static let spacing: CGFloat = 12

    private var columns: [[Article]] {
        var buckets: [[Article]] = Array(repeating: [], count: Self.columnCount)
        for (index, article) in articles.enumerated() {
            buckets[index % Self.columnCount].append(article)
        }
        return buckets
    }

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: Self.spacing) {
                if let headerView {
                    headerView
                }
                HStack(alignment: .top, spacing: Self.spacing) {
                    ForEach(Array(columns.enumerated()), id: \.offset) { _, columnArticles in
                        LazyVStack(spacing: Self.spacing) {
                            ForEach(columnArticles) { article in
                                ArticleLink(article: article, label: {
                                    MasonryArticleCard(article: article)
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
                        .frame(maxWidth: .infinity, alignment: .top)
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
