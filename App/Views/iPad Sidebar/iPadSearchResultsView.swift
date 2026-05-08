import SwiftUI

// swiftlint:disable:next type_name
struct iPadSearchResultsView: View {

    let searchResults: [Article]

    var body: some View {
        Group {
            if searchResults.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "NoResults.Title", table: "Search"),
                          systemImage: "magnifyingglass")
                } description: {
                    Text(String(localized: "NoResults.Description", table: "Search"))
                }
            } else {
                InboxStyleView(articles: searchResults)
                    .sakuraBackground()
            }
        }
        .navigationTitle("Tabs.Search")
        .toolbarTitleDisplayMode(.inline)
    }
}
