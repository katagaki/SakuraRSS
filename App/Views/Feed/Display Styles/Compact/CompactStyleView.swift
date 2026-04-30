import SwiftUI

struct CompactStyleView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.zoomNamespace) private var zoomNamespace
    let articles: [Article]
    var onLoadMore: (() -> Void)?

    private func articleLabel(for article: Article) -> some View {
        HStack {
            Text(article.title)
                .font(.caption)
                .fontWeight(feedManager.isRead(article) ? .regular : .medium)
                .foregroundStyle(feedManager.isRead(article) ? .secondary : .primary)
                .lineLimit(1)

            Spacer()

            if let date = article.publishedDate {
                RelativeTimeText(date: date)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    var body: some View {
        List {
            ForEach(articles) { article in
                ArticleLink(article: article, label: {
                    articleLabel(for: article)
                        .zoomSource(id: article.id, namespace: zoomNamespace)
                        .markReadOnScroll(article: article)
                })
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSpacing(0.0)
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
