import SwiftUI
import Hanami

/// Bookmarks as a sheet rather than a page, the way Safari presents them.
struct BrowserBookmarksSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Namespace private var cardZoom

    var body: some View {
        NavigationStack {
            BookmarksContentView(titleDisplayMode: .inline)
                .environment(\.zoomNamespace, cardZoom)
                .environment(\.navigateToFeed, { _ in })
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "Shared.Done")) {
                            dismiss()
                        }
                    }
                }
                .navigationDestination(for: Feed.self) { feed in
                    FeedArticlesView(feed: feed)
                        .environment(\.zoomNamespace, cardZoom)
                }
                .navigationDestination(for: Article.self) { article in
                    ArticleDestinationView(article: article)
                        .environment(\.zoomNamespace, cardZoom)
                        .zoomTransition(sourceID: article.id, in: cardZoom)
                }
                .navigationDestination(for: EntityDestination.self) { destination in
                    EntityArticlesView(destination: destination)
                        .environment(\.zoomNamespace, cardZoom)
                }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
