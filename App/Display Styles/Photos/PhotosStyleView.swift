import SwiftUI
import Hanami

struct PhotosStyleView: View {

    @Environment(FeedManager.self) var feedManager
    let articles: [Article]
    var onLoadMore: (() -> Void)?
    var headerView: AnyView?

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                if let headerView {
                    headerView
                }
                ForEach(articles) { article in
                    PhotosArticleCard(article: article)
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
