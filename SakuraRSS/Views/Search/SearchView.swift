import SwiftUI

struct SearchView: View {

    @Environment(FeedManager.self) var feedManager
    @AppStorage("Search.DisplayStyle") private var searchDisplayStyle: FeedDisplayStyle = .inbox
    @State private var searchText = ""
    @Namespace private var cardZoom

    private var searchResults: [Article] {
        guard !searchText.isEmpty else { return [] }
        return (try? DatabaseManager.shared.searchArticles(query: searchText)) ?? []
    }

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
        }
    }
}
