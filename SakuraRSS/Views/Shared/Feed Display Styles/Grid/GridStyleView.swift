import SwiftUI

struct GridStyleView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.zoomNamespace) private var zoomNamespace
    let articles: [Article]
    var onLoadMore: (() -> Void)?
    @State private var youTubeArticle: Article?

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
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(articlesWithImages) { article in
                    ArticleLink(article: article, onShowYouTubePlayer: {
                        youTubeArticle = $0
                    }, label: {
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
                                article.isRead
                                    ? String(localized: "Article.MarkUnread", table: "Articles")
                                    : String(localized: "Article.MarkRead", table: "Articles"),
                                systemImage: article.isRead
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
            if let onLoadMore {
                LoadPreviousArticlesButton(action: onLoadMore)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
        }
        .trackScrollActivity()
        .navigationDestination(item: $youTubeArticle) { article in
            YouTubePlayerView(article: article)
                .zoomTransition(sourceID: article.id, in: zoomNamespace)
        }
    }
}
