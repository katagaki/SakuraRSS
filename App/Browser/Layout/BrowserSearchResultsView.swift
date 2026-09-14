import SwiftUI
import Hanami

struct BrowserSearchResultsView: View {

    @Environment(FeedManager.self) private var feedManager
    @AppStorage("Search.DisplayStyle") private var searchDisplayStyle: FeedDisplayStyle = .inbox
    let query: String
    @State private var results: [Article] = []

    private var hasImages: Bool {
        results.contains { $0.imageURL != nil }
    }

    private var effectiveStyle: FeedDisplayStyle {
        if !hasImages && searchDisplayStyle.requiresImages { return .inbox }
        if searchDisplayStyle == .podcast { return .inbox }
        return searchDisplayStyle
    }

    var body: some View {
        DisplayStyleContentView(style: effectiveStyle, articles: results)
            .overlay {
                if results.isEmpty {
                    ContentUnavailableView {
                        Label(String(localized: "NoResults.Title", table: "Search"),
                              systemImage: "magnifyingglass")
                    } description: {
                        Text(String(localized: "NoResults.Description", table: "Search"))
                    }
                }
            }
            .navigationTitle(query)
            .toolbarTitleDisplayMode(.inline)
            .sakuraBackground()
            .task(id: query) {
                let found = (try? DatabaseManager.shared.searchArticles(query: query)) ?? []
                guard !Task.isCancelled else { return }
                withAnimation(.smooth.speed(2.0)) {
                    results = found
                }
                feedManager.recordSearchTerm(query)
            }
    }
}
