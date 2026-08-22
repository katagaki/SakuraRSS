import SwiftUI
import Hanami

struct GridStyleView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.zoomNamespace) private var zoomNamespace
    let articles: [Article]
    var onLoadMore: (() -> Void)?
    var headerView: AnyView?
    private let articlesWithImages: [Article]

    init(articles: [Article], onLoadMore: (() -> Void)? = nil, headerView: AnyView? = nil) {
        self.articles = articles
        self.onLoadMore = onLoadMore
        self.headerView = headerView
        self.articlesWithImages = articles.filter { $0.imageURL != nil }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 12) {
                if let headerView {
                    headerView
                }
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(articlesWithImages) { article in
                        ArticleLink(article: article, label: {
                            GridArticleCell(article: article)
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
                            Divider()
                            ArticleShareMenuButton(article: article)
                            MoveToFolderMenuItems(article: article)
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.top, headerView == nil ? 12 : 0)
                if let onLoadMore {
                    LoadPreviousArticlesButton(action: onLoadMore, articleCount: articles.count)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
            }
            .padding(.bottom)
        }
        .trackScrollActivity()
    }
}
