import SwiftUI
import Hanami

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
                        #if targetEnvironment(macCatalyst)
                        OpenInNewWindowButton(article: article)
                        Divider()
                        #endif
                        ArticleReadMenuButton(article: article, labelStyle: .playedUnplayed)
                        Divider()
                        ArticleBookmarkMenuButton(article: article)
                        ArticleCopyLinkMenuButton(article: article)
                        ArticleShareMenuButton(article: article)
                        MoveToFolderMenuItems(article: article)
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
