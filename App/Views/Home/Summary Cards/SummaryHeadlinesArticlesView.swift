import SwiftUI

/// Article list shown after tapping a summary headline card. Display style
/// is shared across all summary headline lists via its own AppStorage key.
struct SummaryHeadlinesArticlesView: View {

    let destination: SummaryHeadlineDestination

    @Environment(FeedManager.self) var feedManager
    @Environment(\.navigateToEphemeralArticle) private var navigateToEphemeralArticle
    @AppStorage("SummaryHeadlines.DisplayStyle")
    private var displayStyle: FeedDisplayStyle = .inbox
    @State private var articles: [Article] = []
    @Namespace private var cardZoom

    private var hasImages: Bool {
        articles.contains { $0.imageURL != nil }
    }

    private var effectiveStyle: FeedDisplayStyle {
        if !hasImages && displayStyle.requiresImages {
            return .inbox
        }
        if displayStyle == .podcast {
            return .inbox
        }
        return displayStyle
    }

    var body: some View {
        DisplayStyleContentView(
            style: effectiveStyle,
            articles: articles
        )
        .overlay {
            if articles.isEmpty {
                ContentUnavailableView {
                    Label(
                        String(localized: "NoResults.Title", table: "Search"),
                        systemImage: "newspaper"
                    )
                }
            }
        }
        .sakuraBackground()
        .environment(\.zoomNamespace, cardZoom)
        .navigationTitle(destination.title)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    DisplayStylePicker(
                        displayStyle: $displayStyle,
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
        .animation(.smooth.speed(2.0), value: displayStyle)
        .task {
            await loadArticles()
        }
        .onChange(of: feedManager.dataRevision) { _, _ in
            Task { await loadArticles() }
        }
    }

    private func loadArticles() async {
        let database = DatabaseManager.shared
        let ids = destination.articleIDs
        await Task.detached {
            let loaded = ids.compactMap { try? database.article(byID: $0) }
            await MainActor.run {
                articles = loaded
            }
        }.value
    }
}
