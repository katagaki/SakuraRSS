import SwiftUI

struct SearchView: View {

    @Environment(FeedManager.self) var feedManager
    @AppStorage("Search.DisplayStyle") private var searchDisplayStyle: FeedDisplayStyle = .inbox
    @State private var searchText = ""
    @State private var searchResults: [Article] = []
    @State private var path = NavigationPath()
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
        NavigationStack(path: $path) {
            Group {
                if searchText.isEmpty {
                    DiscoverView()
                } else {
                    searchResultsContent
                }
            }
            .scrollContentBackground(.hidden)
            .sakuraBackground()
            .environment(\.zoomNamespace, cardZoom)
            .navigationTitle(searchText.isEmpty
                ? LocalizedStringKey("Discover.Title")
                : LocalizedStringKey("Search.Results.Title"))
            .navigationDestination(for: Article.self) { article in
                Group {
                    if article.isPodcastEpisode {
                        PodcastEpisodeView(article: article)
                    } else {
                        ArticleDetailView(article: article)
                    }
                }
                .environment(\.zoomNamespace, cardZoom)
                .zoomTransition(sourceID: article.id, in: cardZoom)
            }
            .navigationDestination(for: EntityDestination.self) { destination in
                EntityArticlesView(destination: destination)
                    .environment(\.zoomNamespace, cardZoom)
            }
            .toolbar {
                if !searchText.isEmpty {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Menu {
                            DisplayStylePicker(
                                displayStyle: $searchDisplayStyle,
                                hasImages: hasImages,
                                showTimeline: false,
                                showVideo: false,
                                showPodcast: false
                            )
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease")
                        }
                        .menuActionDismissBehavior(.disabled)
                    }
                }
            }
            .animation(.smooth.speed(2.0), value: searchDisplayStyle)
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

    @ViewBuilder
    private var searchResultsContent: some View {
        DisplayStyleContentView(
            style: effectiveStyle,
            articles: searchResults
        )
        .overlay {
            if searchResults.isEmpty {
                ContentUnavailableView {
                    Label("Search.NoResults.Title",
                          systemImage: "magnifyingglass")
                } description: {
                    Text("Search.NoResults.Description")
                }
            }
        }
    }
}
