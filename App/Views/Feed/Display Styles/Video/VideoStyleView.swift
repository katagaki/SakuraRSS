import SwiftUI

struct VideoStyleView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.openURL) var openURL
    @Environment(\.iPadArticleSelection) private var iPadArticleSelection
    @Environment(\.zoomNamespace) private var zoomNamespace
    @AppStorage("YouTube.OpenMode") private var youTubeOpenMode: YouTubeOpenMode = .inAppPlayer
    let articles: [Article]
    var onLoadMore: (() -> Void)?
    var headerView: AnyView?

    @State private var showSafari = false
    @State private var safariURL: URL?

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 12) {
                if let headerView {
                    headerView
                }
                ForEach(articles) { article in
                    Button {
                        feedManager.markRead(article)
                        if iPadArticleSelection != nil {
                            iPadArticleSelection?.wrappedValue = article
                        } else if article.isYouTubeURL && youTubeOpenMode == .inAppPlayer {
                            MediaPresenter.shared.presentYouTube(article)
                        } else if article.isYouTubeURL && youTubeOpenMode == .browser {
                            safariURL = URL(string: article.url)
                            showSafari = true
                        } else {
                            YouTubeHelper.openInApp(url: article.url)
                        }
                    } label: {
                        VideoArticleCard(article: article)
                            .zoomSource(id: article.id, namespace: zoomNamespace)
                            .markReadOnScroll(article: article)
                    }
                    .buttonStyle(.plain)
                    .contentShape(.rect)
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
                            Label(String(localized: "Article.CopyLink", table: "Articles"), systemImage: "link")
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
                        .padding(.horizontal, 16)
                }
            }
            .padding(.top, headerView == nil ? 12 : 0)
            .padding(.bottom)
        }
        .trackScrollActivity()
        .sheet(isPresented: $showSafari) {
            if let safariURL {
                SafariView(url: safariURL)
                    .ignoresSafeArea()
            }
        }
    }
}
