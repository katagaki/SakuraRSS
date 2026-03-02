import SwiftUI

struct BookmarksView: View {

    @Environment(FeedManager.self) var feedManager
    @State private var bookmarkedArticles: [Article] = []

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
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(String(localized: "Tabs.Bookmarks"))
            .scrollContentBackground(.hidden)
            .sakuraBackground()
            .onAppear {
                bookmarkedArticles = (try? DatabaseManager.shared.bookmarkedArticles()) ?? []
            }
        }
    }
}
