import SwiftUI
import Hanami

struct BrowserSearchResultsView: View {

    @Environment(FeedManager.self) private var feedManager
    @AppStorage("Search.DisplayStyle") private var searchDisplayStyle: FeedDisplayStyle = .inbox
    let query: String
    @State private var results: [Article] = []

    /// Ranked, then cut to one row: the grid is a fixed four columns.
    private var matchingFeeds: [Feed] {
        feedManager.feeds
            .compactMap { feed in feed.searchRank(for: query).map { (feed, $0) } }
            .sorted { $0.1 < $1.1 }
            .prefix(BrowserSearchFeedsSection.limit)
            .map(\.0)
    }

    private var hasImages: Bool {
        results.contains { $0.imageURL != nil }
    }

    private var effectiveStyle: FeedDisplayStyle {
        if !hasImages && searchDisplayStyle.requiresImages { return .inbox }
        if searchDisplayStyle == .podcast { return .inbox }
        return searchDisplayStyle
    }

    var body: some View {
        let feeds = matchingFeeds
        return DisplayStyleContentView(
            style: effectiveStyle,
            articles: results,
            headerView: feeds.isEmpty ? nil : AnyView(BrowserSearchFeedsSection(feeds: feeds))
        )
            .overlay {
                if results.isEmpty && feeds.isEmpty {
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
