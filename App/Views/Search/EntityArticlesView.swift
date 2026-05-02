import SwiftUI

struct EntityArticlesView: View {

    let destination: EntityDestination
    @Environment(FeedManager.self) var feedManager
    @Environment(\.navigateToEphemeralArticle) private var navigateToEphemeralArticle
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
                    Label(String(localized: "NoResults.Title", table: "Search"),
                          systemImage: "magnifyingglass")
                }
            }
        }
        .sakuraBackground()
        .environment(\.zoomNamespace, cardZoom)
        .navigationDestination(for: Article.self) { article in
            ArticleDestinationView(article: article)
                .environment(\.zoomNamespace, cardZoom)
                .environment(\.navigateToEphemeralArticle, navigateToEphemeralArticle)
                .zoomTransition(sourceID: article.id, in: cardZoom)
        }
        .navigationDestination(for: EntityDestination.self) { destination in
            EntityArticlesView(destination: destination)
                .environment(\.zoomNamespace, cardZoom)
                .environment(\.navigateToEphemeralArticle, navigateToEphemeralArticle)
        }
        .navigationTitle(destination.name)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    DisplayStylePicker(
                        displayStyle: $searchDisplayStyle,
                        hasImages: hasImages,
                        showTimeline: false,
                        showPodcast: false
                    )
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                }
                .menuActionDismissBehavior(.disabled)
            }
        }
        .animation(.smooth.speed(2.0), value: searchDisplayStyle)
        .task {
            await loadArticles()
        }
    }

    private func loadArticles() async {
        let database = DatabaseManager.shared
        let name = destination.name
        let types = destination.types
        await Task.detached {
            let ids: [Int64]
            if types.count == 1 {
                ids = (try? database.articleIDs(forEntity: name, type: types[0])) ?? []
            } else {
                ids = (try? database.articleIDs(forEntity: name, types: types)) ?? []
            }
            let loaded = ids.compactMap { try? database.article(byID: $0) }
            await MainActor.run {
                articles = loaded
            }
        }.value
    }
}
