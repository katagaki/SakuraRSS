import SwiftUI

struct SearchView: View {

    @Environment(FeedManager.self) var feedManager
    @AppStorage("Search.DisplayStyle") private var searchDisplayStyle: FeedDisplayStyle = .inbox
    @State private var searchText = ""
    @State private var searchResults: [Article] = []
    @Namespace private var cardZoom

    private var hasImages: Bool {
        searchResults.contains { $0.imageURL != nil }
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
        NavigationStack {
            Group {
                if searchText.isEmpty {
                    ContentUnavailableView {
                        Label("Search.Empty.Title",
                              systemImage: "magnifyingglass")
                    } description: {
                        Text("Search.Empty.Description")
                    }
                } else if searchResults.isEmpty {
                    ContentUnavailableView {
                        Label("Search.NoResults.Title",
                              systemImage: "magnifyingglass")
                    } description: {
                        Text("Search.NoResults.Description")
                    }
                } else {
                    DisplayStyleContentView(
                        style: effectiveStyle,
                        articles: searchResults
                    )
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
            .searchable(text: $searchText, prompt: "Search.Prompt")
            .task(id: searchText) {
                let query = searchText
                guard !query.isEmpty else {
                    withAnimation(.smooth.speed(2.0)) {
                        searchResults = []
                    }
                    return
                }
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled, searchText == query else { return }
                let results = (try? DatabaseManager.shared.searchArticles(query: query)) ?? []
                withAnimation(.smooth.speed(2.0)) {
                    searchResults = results
                }
            }
        }
    }
}
