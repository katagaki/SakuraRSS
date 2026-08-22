import SwiftUI
import Hanami

struct MagazineStyleView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.zoomNamespace) private var zoomNamespace
    let articles: [Article]
    var onLoadMore: (() -> Void)?
    var headerView: AnyView?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 12) {
                if let headerView {
                    headerView
                }
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(articles) { article in
                        ArticleLink(article: article, label: {
                            MagazineArticleCard(article: article)
                                .zoomSource(id: article.id, namespace: zoomNamespace)
                                .markReadOnScroll(article: article)
                        })
                        .buttonStyle(.plain)
                        .contextMenu {
                            #if targetEnvironment(macCatalyst)
                            OpenInNewWindowButton(article: article)
                            Divider()
                            #endif
                            ArticleReadMenuButton(article: article)
                            ArticleBookmarkMenuButton(article: article)
                            MoveToFolderMenuItems(article: article)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, headerView == nil ? 12 : 0)
                if let onLoadMore {
                    LoadPreviousArticlesButton(action: onLoadMore, articleCount: articles.count)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.bottom)
        }
        .trackScrollActivity()
    }
}
