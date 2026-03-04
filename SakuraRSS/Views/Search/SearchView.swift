import SwiftUI

struct SearchView: View {

    @Environment(FeedManager.self) var feedManager
    @AppStorage("Search.DisplayStyle") private var searchDisplayStyle: FeedDisplayStyle = .inbox
    @State private var searchText = ""

    private var searchResults: [Article] {
        guard !searchText.isEmpty else { return [] }
        return (try? DatabaseManager.shared.searchArticles(query: searchText)) ?? []
    }

    private var hasImages: Bool {
        searchResults.contains { $0.imageURL != nil }
    }

    private var effectiveStyle: FeedDisplayStyle {
        if !hasImages && (searchDisplayStyle == .magazine || searchDisplayStyle == .photos) {
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
                        Label(String(localized: "Search.Empty.Title"),
                              systemImage: "magnifyingglass")
                    } description: {
                        Text("Search.Empty.Description")
                    }
                } else if searchResults.isEmpty {
                    ContentUnavailableView {
                        Label(String(localized: "Search.NoResults.Title"),
                              systemImage: "magnifyingglass")
                    } description: {
                        Text("Search.NoResults.Description")
                    }
                } else {
                    switch effectiveStyle {
                    case .inbox:
                        InboxStyleView(articles: searchResults)
                    case .feed:
                        FeedStyleView(articles: searchResults)
                    case .magazine:
                        MagazineStyleView(articles: searchResults)
                    case .compact:
                        CompactStyleView(articles: searchResults)
                    case .video:
                        VideoStyleView(articles: searchResults)
                    case .photos:
                        PhotosStyleView(articles: searchResults)
                    case .podcast:
                        PodcastStyleView(articles: searchResults)
                    case .timeline:
                        TimelineStyleView(articles: searchResults)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .sakuraBackground()
            .navigationDestination(for: Article.self) { article in
                if article.isPodcastEpisode {
                    PodcastEpisodeView(article: article)
                } else {
                    ArticleDetailView(article: article)
                }
            }
            .searchable(text: $searchText, prompt: String(localized: "Search.Prompt"))
        }
    }
}
