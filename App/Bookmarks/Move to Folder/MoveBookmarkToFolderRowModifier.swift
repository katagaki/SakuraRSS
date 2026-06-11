import SwiftUI
import Hanami

/// Makes article rows in the Bookmarks tab draggable into folders and adds
/// a trailing swipe action that picks a destination folder. Inert elsewhere.
struct MoveBookmarkToFolderRowModifier: ViewModifier {

    @Environment(\.allowsMovingBookmarksToFolders) private var allowsMoving
    @Environment(FeedManager.self) private var feedManager
    let article: Article

    @State private var isShowingFolderPicker = false
    @State private var destinationFolders: [BookmarkFolder] = []

    func body(content: Content) -> some View {
        if allowsMoving && !feedManager.bookmarkFolders.isEmpty {
            content
                .draggable(BookmarkDragPayload.encode(articleID: article.id))
                .swipeActions(edge: .trailing) {
                    Button {
                        let currentFolderID = feedManager.bookmarkFolderID(forArticleID: article.id)
                        destinationFolders = feedManager.bookmarkFolders
                            .filter { $0.id != currentFolderID }
                        isShowingFolderPicker = true
                    } label: {
                        Image(systemName: "folder")
                    }
                    .tint(.indigo)
                }
                .confirmationDialog(
                    String(localized: "Article.MoveToFolder", table: "Articles"),
                    isPresented: $isShowingFolderPicker,
                    titleVisibility: .visible
                ) {
                    ForEach(destinationFolders) { folder in
                        Button(folder.name) {
                            withAnimation(.smooth.speed(2.0)) {
                                feedManager.moveBookmark(articleID: article.id, to: folder)
                            }
                        }
                    }
                    Button("Shared.Cancel", role: .cancel) { }
                }
        } else {
            content
        }
    }
}
