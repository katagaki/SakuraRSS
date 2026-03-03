import SwiftUI

struct SearchView: View {

    @Environment(FeedManager.self) var feedManager
    @AppStorage("searchDisplayStyle") private var searchDisplayStyle: String = FeedDisplayStyle.inbox.rawValue
    @State private var searchText = ""

    private var searchResults: [Article] {
        guard !searchText.isEmpty else { return [] }
        return (try? DatabaseManager.shared.searchArticles(query: searchText)) ?? []
    }

    private var displayStyle: FeedDisplayStyle {
        FeedDisplayStyle(rawValue: searchDisplayStyle) ?? .inbox
    }

    private var hasImages: Bool {
        searchResults.contains { $0.imageURL != nil }
    }

    private var effectiveStyle: FeedDisplayStyle {
        if !hasImages && (displayStyle == .magazine || displayStyle == .photos) {
            return .inbox
        }
        return displayStyle
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
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .sakuraBackground()
            .searchable(text: $searchText, prompt: String(localized: "Search.Prompt"))
        }
    }
}
