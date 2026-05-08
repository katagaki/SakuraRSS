import SwiftUI

struct VideoStyleView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.zoomNamespace) private var zoomNamespace
    let articles: [Article]
    var onLoadMore: (() -> Void)?
    var headerView: AnyView?

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 12) {
                if let headerView {
                    headerView
                }
                ForEach(articles) { article in
                    ArticleLink(article: article, label: {
                        VideoArticleCard(article: article)
                            .zoomSource(id: article.id, namespace: zoomNamespace)
                            .markReadOnScroll(article: article)
                    })
                    .buttonStyle(.plain)
                    .contentShape(.rect)
                    .contextMenu {
                        Button {
                            feedManager.toggleRead(article)
                        } label: {
                            Label(
                                feedManager.isRead(article)
                                    ? String(localized: "Article.MarkUnplayed", table: "Articles")
                                    : String(localized: "Article.MarkPlayed", table: "Articles"),
                                systemImage: feedManager.isRead(article) ? "arrow.uturn.backward" : "checkmark"
                            )
                        }
                        Divider()
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
                        Button {
                            UIPasteboard.general.string = article.url
                        } label: {
                            Label(String(localized: "Article.CopyLink", table: "Articles"), systemImage: "link")
                        }
                        if let shareURL = URL(string: article.url) {
                            ShareLink(item: shareURL) {
                                Label(
                                    String(localized: "Article.Share", table: "Articles"),
                                    systemImage: "square.and.arrow.up"
                                )
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
                if let onLoadMore {
                    LoadPreviousArticlesButton(action: onLoadMore, articleCount: articles.count)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.top, headerView == nil ? 12 : 0)
            .padding(.bottom)
        }
        .trackScrollActivity()
    }
}
