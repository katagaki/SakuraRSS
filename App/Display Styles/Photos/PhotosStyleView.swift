import SwiftUI
import Hanami

struct PhotosStyleView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.zoomNamespace) private var zoomNamespace
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
                        .zoomSource(id: article.id, namespace: zoomNamespace)
                        .markReadOnScroll(article: article)
                        .contextMenu {
                            MoveToFolderMenuItems(article: article)
                        }
                        // Lazy containers reuse the context menu interaction, which can
                        // present the previously long-pressed item's menu without an
                        // explicit identity.
                        .id(article.id)
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
