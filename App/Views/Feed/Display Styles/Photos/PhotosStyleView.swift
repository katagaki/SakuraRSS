import SwiftUI

struct PhotosStyleView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.zoomNamespace) private var zoomNamespace
    let articles: [Article]
    var onLoadMore: (() -> Void)?

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(articles) { article in
                    PhotosArticleCard(article: article)
                        .zoomSource(id: article.id, namespace: zoomNamespace)
                        .markReadOnScroll(article: article)
                }
                if let onLoadMore {
                    LoadPreviousArticlesButton(action: onLoadMore, articleCount: articles.count)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                }
            }
        }
        .trackScrollActivity()
    }
}
