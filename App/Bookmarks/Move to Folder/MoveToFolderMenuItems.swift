import SwiftUI
import Hanami

/// "Move to Folder" submenu appended to article context menus.
/// Renders nothing outside the Bookmarks tab.
struct MoveToFolderMenuItems: View {

    @Environment(\.allowsMovingBookmarksToFolders) private var allowsMoving
    @Environment(FeedManager.self) private var feedManager
    let article: Article

    private var destinationFolders: [BookmarkFolder] {
        let currentFolderID = feedManager.bookmarkFolderID(forArticleID: article.id)
        return feedManager.bookmarkFolders.filter { $0.id != currentFolderID }
    }

    var body: some View {
        if allowsMoving && !feedManager.bookmarkFolders.isEmpty {
            Divider()
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
