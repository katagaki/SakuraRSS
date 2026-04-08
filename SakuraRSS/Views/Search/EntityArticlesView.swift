import SwiftUI

struct EntityDestination: Hashable {
    let name: String
    let types: [String]
}

struct EntityArticlesView: View {

    let destination: EntityDestination
    @Environment(FeedManager.self) var feedManager
    @AppStorage("Search.DisplayStyle") private var searchDisplayStyle: FeedDisplayStyle = .inbox
    @State private var articles: [Article] = []
    @Namespace private var cardZoom

    private var hasImages: Bool {
        articles.contains { $0.imageURL != nil }
    }

    private var effectiveStyle: FeedDisplayStyle {
        if !hasImages && searchDisplayStyle.requiresImages {
            return .inbox
        }
        if searchDisplayStyle == .podcast {
            return .inbox
        }
        return searchDisplayStyle
    }

    var body: some View {
        DisplayStyleContentView(
            style: effectiveStyle,
            articles: articles
        )
        .overlay {
            if articles.isEmpty {
                ContentUnavailableView {
                    Label("Search.NoResults.Title",
                          systemImage: "magnifyingglass")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .sakuraBackground()
        .environment(\.zoomNamespace, cardZoom)
        .navigationDestination(for: Article.self) { article in
            Group {
                if article.isPodcastEpisode {
                    PodcastEpisodeView(article: article)
                } else {
                    ArticleDetailView(article: article)
                }
            }
            .zoomTransition(sourceID: article.id, in: cardZoom)
        }
        .navigationTitle(destination.name)
        .toolbarTitleDisplayMode(.inline)
        .task {
            await loadArticles()
        }
    }

    private func loadArticles() async {
        let db = DatabaseManager.shared
        let name = destination.name
        let types = destination.types
        await Task.detached {
            let ids: [Int64]
            if types.count == 1 {
                ids = (try? db.articleIDs(forEntity: name, type: types[0])) ?? []
            } else {
                ids = (try? db.articleIDs(forEntity: name, types: types)) ?? []
            }
            let loaded = ids.compactMap { try? db.article(byID: $0) }
            await MainActor.run {
                articles = loaded
            }
        }.value
    }
}
