import SwiftUI

/// Full-screen vertical pager; tap to expand an article, overscroll to navigate.
struct ScrollStyleView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.zoomNamespace) private var zoomNamespace
    let articles: [Article]
    var onLoadMore: (() -> Void)?

    @State private var currentID: ScrollPageID?
    @State private var expandedArticleID: Int64?
    @State private var youTubeArticle: Article?
    @State private var podcastArticle: Article?
    @State private var contextInsets: EdgeInsets = EdgeInsets()

    @AppStorage("YouTube.OpenMode") private var youTubeOpenMode: YouTubeOpenMode = .inAppPlayer

    var body: some View {
        Color.clear
            .overlay {
                GeometryReader { geometry in
                    let pageSize = geometry.size

                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(articles) { article in
                                ScrollArticlePage(
                                    article: article,
                                    pageSize: pageSize,
                                    contextInsets: contextInsets,
                                    isExpanded: expandedArticleID == article.id,
                                    onTapContent: { handleTap(on: article) },
                                    onAdvance: { advance(from: article) }
                                )
                                .frame(width: pageSize.width, height: pageSize.height)
                                .id(ScrollPageID.article(article.id))
                            }
                            if onLoadMore != nil {
                                ScrollEndOfFeedPage(
                                    pageSize: pageSize,
                                    onLoadMore: { onLoadMore?() }
                                )
                                .frame(width: pageSize.width, height: pageSize.height)
                                .id(ScrollPageID.endOfFeed)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: $currentID, anchor: .center)
                    .scrollDisabled(expandedArticleID != nil)
                    .onChange(of: currentID) { oldValue, _ in
                        if case .article(let id) = oldValue,
                           let prev = articles.first(where: { $0.id == id }) {
                            feedManager.markRead(prev)
                        }
                    }
                    .onChange(of: articles.count) { oldValue, newValue in
                        guard newValue > oldValue,
                              currentID == .endOfFeed,
                              oldValue < articles.count else { return }
                        let firstNew = articles[oldValue]
                        withAnimation(.smooth.speed(1.5)) {
                            currentID = .article(firstNew.id)
                        }
                    }
                }
                .ignoresSafeArea(.container, edges: .vertical)
            }
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { contextInsets = proxy.safeAreaInsets }
                        .onChange(of: proxy.safeAreaInsets) { _, new in contextInsets = new }
                }
            }
            .background(Color.black.ignoresSafeArea())
            .scrollEdgeEffectHidden(true, for: .all)
        .navigationDestination(item: $youTubeArticle) { article in
            YouTubePlayerView(article: article)
                .zoomTransition(sourceID: article.id, in: zoomNamespace)
        }
        .navigationDestination(item: $podcastArticle) { article in
            PodcastEpisodeView(article: article)
                .zoomTransition(sourceID: article.id, in: zoomNamespace)
        }
    }

    private func handleTap(on article: Article) {
        if article.isYouTubeURL && youTubeOpenMode == .inAppPlayer {
            feedManager.markRead(article)
            youTubeArticle = article
            return
        }
        if article.isPodcastEpisode {
            feedManager.markRead(article)
            podcastArticle = article
            return
        }
        withAnimation(.smooth.speed(1.5)) {
            if expandedArticleID == article.id {
                expandedArticleID = nil
            } else {
                feedManager.markRead(article)
                expandedArticleID = article.id
            }
        }
    }

    private func advance(from article: Article) {
        guard let idx = articles.firstIndex(where: { $0.id == article.id }) else { return }
        withAnimation(.smooth.speed(1.5)) {
            expandedArticleID = nil
            if idx + 1 < articles.count {
                currentID = .article(articles[idx + 1].id)
            } else if onLoadMore != nil {
                currentID = .endOfFeed
            }
        }
    }
}

// MARK: - Page identifier

private enum ScrollPageID: Hashable {
    case article(Int64)
    case endOfFeed
}
