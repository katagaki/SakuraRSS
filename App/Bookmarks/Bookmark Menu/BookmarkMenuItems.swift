import SwiftUI
import Hanami

/// Bookmark-only actions appended to article context menus.
/// Renders nothing outside Bookmarks surfaces.
struct BookmarkMenuItems: View {

    @Environment(\.isBookmarksSurface) private var isBookmarksSurface
    @Environment(FeedManager.self) private var feedManager
    @Environment(BookmarkDetailPresenter.self) private var detailPresenter: BookmarkDetailPresenter?

    let article: Article

    private var destinationFolders: [BookmarkFolder] {
        let currentFolderID = feedManager.bookmarkFolderID(forArticleID: article.id)
        return feedManager.bookmarkFolders.filter { $0.id != currentFolderID }
    }

    var body: some View {
        if isBookmarksSurface {
            Divider()
            Button {
                detailPresenter?.article = article
            } label: {
                Label(String(localized: "Article.BookmarkDetails", table: "Articles"),
                      systemImage: "pencil")
            }
            if !feedManager.bookmarkFolders.isEmpty {
                Menu {
                    ForEach(destinationFolders) { folder in
                        Button {
                            withAnimation(.smooth.speed(2.0)) {
                                feedManager.moveBookmark(articleID: article.id, to: folder)
                            }
                        } label: {
                            Label(folder.name, systemImage: folder.icon)
                        }
                    }
                } label: {
                    Label(String(localized: "Article.MoveToFolder", table: "Articles"),
                          systemImage: "folder")
                }
            }
        }
    }
}
