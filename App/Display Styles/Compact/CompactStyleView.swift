import SwiftUI
import Hanami

struct CompactStyleView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.zoomNamespace) private var zoomNamespace
    let articles: [Article]
    var onLoadMore: (() -> Void)?
    var headerView: AnyView?
    var usesStackLayout: Bool = false

    private func articleLabel(for article: Article) -> some View {
        let isRead = feedManager.isRead(article)
        return HStack(alignment: .top) {
            Text(article.title)
                .font(.caption)
                .fontWeight(isRead ? .regular : .medium)
                .foregroundStyle(isRead ? .secondary : .primary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let date = article.publishedDate {
                RelativeTimeText(date: date)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    var body: some View {
        if usesStackLayout {
            stackLayout
        } else {
            listLayout
        }
    }

    private var listLayout: some View {
        List {
            if let headerView {
                headerView
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
            }
            ForEach(articles) { article in
                articleRow(article)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSpacing(0.0)
                    .listRowSeparator(.hidden, edges: .top)
                    .listRowSeparator(.visible, edges: .bottom)
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

    private var stackLayout: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                if let headerView {
                    headerView
                }
                ForEach(articles) { article in
                    articleRow(article)
                        .buttonStyle(.plain)
                        .padding(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        // Lazy containers reuse the context menu interaction, which can
                        // present the previously long-pressed item's menu without an
                        // explicit identity.
                        .id(article.id)
                    Divider()
                        .padding(.horizontal, 16)
                }
                if let onLoadMore {
                    LoadPreviousArticlesButton(action: onLoadMore, articleCount: articles.count)
                }
            }
        }
        .trackScrollActivity()
    }

    private func articleRow(_ article: Article) -> some View {
        ArticleLink(article: article, label: {
            articleLabel(for: article)
                .zoomSource(id: article.id, namespace: zoomNamespace)
                .markReadOnScroll(article: article)
                .contentShape(.rect)
        })
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
