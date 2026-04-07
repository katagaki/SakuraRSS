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
                    })
                    .buttonStyle(.plain)
                }
            }
            if let onLoadMore {
                LoadPreviousArticlesButton(action: onLoadMore)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
        }
        .navigationDestination(item: $youTubeArticle) { article in
            YouTubePlayerView(article: article)
                .zoomTransition(sourceID: article.id, in: zoomNamespace)
        }
    }
}

struct GridArticleCell: View {

    let article: Article

    var body: some View {
        GeometryReader { geometry in
            if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                CachedAsyncImage(url: url) {
                    Rectangle()
                        .fill(.secondary.opacity(0.15))
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .contentShape(.rect)
    }
}
