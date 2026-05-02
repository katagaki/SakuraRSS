import SwiftUI

struct PodcastStyleView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.zoomNamespace) private var zoomNamespace
    @Environment(\.iPadArticleSelection) private var iPadArticleSelection
    let articles: [Article]
    var onLoadMore: (() -> Void)?
    var headerView: AnyView?

    var body: some View {
        List {
            if let headerView {
                headerView
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
            }
            ForEach(articles) { article in
                ZStack {
                    if let iPadArticleSelection {
                        Button {
                            feedManager.markRead(article)
                            iPadArticleSelection.wrappedValue = article
                        } label: {
                            EmptyView()
                        }
                        .opacity(0)
                    } else {
                        Button {
                            feedManager.markRead(article)
                            MediaPresenter.shared.presentPodcast(article)
                        } label: {
                            EmptyView()
                        }
                        .opacity(0)
                    }

                    PodcastEpisodeRow(article: article)
                        .zoomSource(id: article.id, namespace: zoomNamespace)
                        .markReadOnScroll(article: article)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden, edges: .top)
                .listRowSeparator(.visible, edges: .bottom)
                .swipeActions(edge: .leading) {
                    Button {
                        withAnimation(.smooth.speed(2.0)) {
                            feedManager.toggleRead(article)
                        }
                    } label: {
                        Image(systemName: feedManager.isRead(article) ? "arrow.uturn.backward" : "checkmark")
                    }
                    .tint(.blue)
                }
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
                            article.isBookmarked
                                ? String(localized: "Article.RemoveBookmark", table: "Articles")
                                : String(localized: "Article.Bookmark", table: "Articles"),
                            systemImage: article.isBookmarked ? "bookmark.fill" : "bookmark"
                        )
                    }
                    Button {
                        UIPasteboard.general.string = article.url
                    } label: {
                        Label(
                            String(localized: "Article.CopyLink", table: "Articles"),
                            systemImage: "link"
                        )
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
}
