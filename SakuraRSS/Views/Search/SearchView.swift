import SwiftUI

struct SearchView: View {

    enum SearchTab: String, CaseIterable {
        case search, topics, people
    }

    @Environment(FeedManager.self) var feedManager
    @AppStorage("Search.DisplayStyle") private var searchDisplayStyle: FeedDisplayStyle = .inbox
    @AppStorage("Intelligence.TopicsPeople.Enabled") private var topicsPeopleEnabled: Bool = false
    @State private var searchText = ""
    @State private var searchResults: [Article] = []
    @State private var selectedTab: SearchTab = .search
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
            VStack(spacing: 0) {
                if topicsPeopleEnabled {
                    Picker("", selection: $selectedTab) {
                        Text("Search.Tab.Search").tag(SearchTab.search)
                        Text("Search.Tab.Topics").tag(SearchTab.topics)
                        Text("Search.Tab.People").tag(SearchTab.people)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                Group {
                    switch selectedTab {
                    case .search:
                        searchContent
                    case .topics:
                        TopicsView()
                    case .people:
                        PeopleView()
                    }
                }
                .frame(maxHeight: .infinity)
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
            .navigationDestination(for: EntityDestination.self) { destination in
                EntityArticlesView(destination: destination)
            }
            .toolbar {
                if selectedTab == .search {
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
            .animation(.smooth.speed(2.0), value: selectedTab)
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
            .onChange(of: selectedTab) {
                if selectedTab != .search {
                    searchText = ""
                }
            }
        }
    }

    @ViewBuilder
    private var searchContent: some View {
        DisplayStyleContentView(
            style: effectiveStyle,
            articles: searchResults
        )
        .overlay {
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
            }
        }
    }
}
