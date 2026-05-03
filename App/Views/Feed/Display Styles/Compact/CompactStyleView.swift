import SwiftUI

struct CompactStyleView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.zoomNamespace) private var zoomNamespace
    let articles: [Article]
    var onLoadMore: (() -> Void)?
    var headerView: AnyView?

    private func articleLabel(for article: Article) -> some View {
        HStack {
            Text(article.title)
                .font(.caption)
                .fontWeight(feedManager.isRead(article) ? .regular : .medium)
                .foregroundStyle(feedManager.isRead(article) ? .secondary : .primary)
                .lineLimit(1)
                .feedMatchedGeometry("Title.\(article.id)")

            Spacer()

            if let date = article.publishedDate {
                RelativeTimeText(date: date)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                if let headerView {
                    headerView
                }
                ForEach(articles) { article in
                    VStack(spacing: 0) {
                        ArticleLink(article: article, label: {
                            articleLabel(for: article)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .contentShape(.rect)
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
                                    systemImage: feedManager.isRead(article) ? "envelope" : "envelope.open"
                                )
                            }
                            Button {
                                feedManager.toggleBookmark(article)
                            } label: {
                                Label(
                                    article.isBookmarked
                                        ? String(localized: "Article.RemoveBookmark", table: "Articles")
                                        : String(localized: "Article.Bookmark", table: "Articles"),
                                    systemImage: article.isBookmarked ? "bookmark.fill" : "bookmark"
                                )
                            }
                        }
                        Divider()
                            .padding(.leading, 16)
                    }
                }
                if let onLoadMore {
                    LoadPreviousArticlesButton(action: onLoadMore, articleCount: articles.count)
                }
            }
        }
        .trackScrollActivity()
    }
}
