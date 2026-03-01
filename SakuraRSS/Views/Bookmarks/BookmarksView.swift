import SwiftUI

struct BookmarksView: View {

    @Environment(FeedManager.self) var feedManager

    private var bookmarkedArticles: [Article] {
        (try? DatabaseManager.shared.bookmarkedArticles()) ?? []
    }

    var body: some View {
        NavigationStack {
            Group {
                if bookmarkedArticles.isEmpty {
                    ContentUnavailableView {
                        Label(String(localized: "Bookmarks.Empty.Title"),
                              systemImage: "bookmark")
                    } description: {
                        Text(String(localized: "Bookmarks.Empty.Description"))
                    }
                } else {
                    List(bookmarkedArticles) { article in
                        NavigationLink {
                            ArticleDetailView(article: article)
                        } label: {
                            InboxArticleRow(article: article)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(String(localized: "Tabs.Bookmarks"))
        }
    }
}
